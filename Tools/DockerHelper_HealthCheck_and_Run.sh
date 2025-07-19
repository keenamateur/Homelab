# This script checks the health of specified Docker containers and attempts to recover them if they are not running.
# It also ensures that the containers are ready before proceeding with further operations.

#!/bin/bash

# Space-separated list of containers
CHECK_CONTAINERS="n8n postgres_n8n"

# Function to check and recover container state
check_and_recover_container() {
    local container_name=$1
    local timeout=20
    
    echo "Checking state of $container_name..."
    container_status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
    
    if [[ "$container_status" != "running" ]]; then
        echo "Warning: $container_name is not running ($container_status). Attempting recovery..."
        docker compose down "$container_name" && docker compose up -d "$container_name"
        sleep $timeout
        
        container_status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
        [[ "$container_status" != "running" ]] && { echo "Recovery failed"; return 1; }
    fi
    
    echo "$container_name is running normally"
    return 0
}

# Function to verify container readiness
check_container_ready() {
    local container_name=$1
    local timeout=30

    for ((i=0; i<timeout; i++)); do
        container_status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
        health_status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null)
        
        if [[ "$container_status" == "running" && ("$health_status" == "healthy" || -z "$health_status") ]]; then
            echo "$container_name is ready"
            return 0
        fi
        sleep 1
    done
    
    echo "Timeout: $container_name not ready"
    return 1
}

# Main execution
for container in $CHECK_CONTAINERS; do 
    check_and_recover_container "$container" || exit 1
    check_container_ready "$container" || exit 1
done

## lan
docker exec -it n8n ip route del 192.168.0.0/16 via 172.30.10.1 dev eth0
docker exec -it n8n ip route add 192.168.0.0/16 via 172.30.10.1 dev eth0

exit 0

