#!/bin/bash

# Docker - routes

#add vpn route to host
ip route del 10.10.30.0/24 via 172.30.10.30 dev proxy_net
ip route add 10.10.30.0/24 via 172.30.10.30 dev proxy_net
#give access to the host
iptables -D TCP -p tcp -m multiport --dports 20,21,53,81,139,445,3389,3480,8080,8123 -s 172.30.10.30 -j ACCEPT
iptables -I TCP 1 -p tcp -m multiport --dports 20,21,53,81,139,445,3389,3480,8080,8123 -s 172.30.10.30 -j ACCEPT

iptables -D TCP -p tcp -m multiport --dports 9000,9443,50053,53001,51831 -s 172.30.10.30 -j ACCEPT
iptables -I TCP 1 -p tcp -m multiport --dports 9000,9443,50053,53001,51831 -s 172.30.10.30 -j ACCEPT

# WG->LAN
docker exec -it wg_proxy iptables -A FORWARD -i wg0 -o eth0 -d 192.168.0.0/16 -j ACCEPT
docker exec -it wg_proxy iptables -A FORWARD -i eth0 -o wg0 -s 192.168.0.0/16 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
docker exec -it wg_proxy iptables -t nat -A POSTROUTING -s 10.10.30.0/24 -o eth0 -d 192.168.0.0/16 -j MASQUERADE
docker exec -it wg_proxy iptables -t nat -A POSTROUTING -s 10.10.30.0/24 -o eth0 -d 172.30.10.0/24 -j MASQUERADE
docker exec -it wg_proxy ip route add 192.168.0.0/16 via 172.30.10.1 dev eth0
# NODERED->WG (CLIENT)
docker exec -it wg_proxy iptables -A FORWARD -i eth0 -o wg0 -s 172.30.10.0/24 -d 10.10.30.0/24 -j ACCEPT
docker exec -it wg_proxy iptables -A FORWARD -i wg0 -o eth0 -s 10.10.30.0/24 -d 172.30.10.0/24 -j ACCEPT
docker exec -it wg_proxy iptables -t nat -A POSTROUTING -s 172.30.10.0/24 -o wg0 -d 10.10.30.0/24 -j MASQUERADE
# NODERED->WG (IP ROUTE)
docker exec -it nodered ip route del 10.10.30.0/24 via 172.30.10.30 dev eth0
docker exec -it nodered ip route add 10.10.30.0/24 via 172.30.10.30 dev eth0
