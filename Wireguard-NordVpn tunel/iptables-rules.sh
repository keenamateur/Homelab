#!/bin/bash

WG_CONTAINER="YOUR_WIREGUARD_CONTAINER_NAME"  # wg_de
#WG_SUBNET="10.10.10.0/24"  
VPN_CONTAINER="YOUR_NORDVPN_CONTAINER_NAME"   # nvpn_de
LAN_SUBNET="192.168.0.0/16"
ETH="enp3s0"

# WireGuard & NordVPN data
#WG_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $WG_CONTAINER)
WG_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $WG_CONTAINER)
WG_NET_ID=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' $WG_CONTAINER)
WG_SUBNET=$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' $WG_NET_ID)

VPN_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $VPN_CONTAINER)
VPN_NET_ID=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' $VPN_CONTAINER)
VPN_SUBNET=$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' $VPN_NET_ID)

# Docker - routes

ip route del $WG_SUBNET via $VPN_IP dev proxy_net
ip route add $WG_SUBNET via $VPN_IP dev proxy_net
iptables -L TCP > /dev/null 2>&1 || iptables -N TCP  # create TCP table

#iptables -A INPUT -p tcp --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j TCP   # maybe - if you know where to place it 
iptables -I INPUT 1 -p tcp --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j TCP

iptables -D TCP -p tcp -m multiport --dports 20,21,81,139,445 -s $VPN_IP -j ACCEPT   # ftp (active), 81, smb
iptables -I TCP 1 -p tcp -m multiport --dports 20,21,81,139,445 -s $VPN_IP -j ACCEPT
iptables -D TCP -p tcp -m multiport --dports 9000,9443,51821 -s $VPN_IP -j ACCEPT     # portainer, very secure portainer, wireguard
iptables -I TCP 1 -p tcp -m multiport --dports 9000,9443,51821 -s $VPN_IP -j ACCEPT
iptables -A TCP -j RETURN   # maybe

# WG->NORD
docker exec -it $VPN_CONTAINER iptables -A FORWARD -i wg0 -o tun0 -j ACCEPT
docker exec -it $VPN_CONTAINER iptables -A FORWARD -i tun0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
docker exec -it $VPN_CONTAINER iptables -t nat -A POSTROUTING -s $WG_SUBNET -o tun0 -j MASQUERADE

# LAN
docker exec -it $VPN_CONTAINER iptables -A FORWARD -i wg0 -s $WG_SUBNET -o eth0 -d $LAN_SUBNET -j ACCEPT
docker exec -it $VPN_CONTAINER iptables -A FORWARD -i eth0 -o wg0 -s $LAN_SUBNET -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
docker exec -it $VPN_CONTAINER iptables -t nat -A POSTROUTING -s $WG_SUBNET -o eth0 -d $LAN_SUBNET -j MASQUERADE
docker exec -it $VPN_CONTAINER iptables -t nat -A POSTROUTING -s $WG_SUBNET -o eth0 -d $VPN_SUBNET -j MASQUERADE
docker exec -it $WG_CONTAINER ip route add $LAN_SUBNET via 172.30.10.1 dev eth0

# IP ROUTE
docker exec -it nodered ip route del $WG_SUBNET via $VPN_IP dev eth0
docker exec -it nodered ip route add $WG_SUBNET via $VPN_IP dev eth0
