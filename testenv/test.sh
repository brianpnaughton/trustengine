#!/bin/bash

# VyOS Docker Network Deployment Script
# This script deploys 2 VyOS docker containers on the same docker network

set -e  # Exit on any error

# Configuration
NETWORK_NAME="vyos-network"
SUBNET="172.20.0.0/24"
SUBNET_IPV6="fd00:172:20::/64"
VYOS_IMAGE="vyos:1.5"
CONTAINER1_NAME="vyos-router1"
CONTAINER2_NAME="vyos-router2"
CONTAINER1_IP="172.20.0.10"
CONTAINER2_IP="172.20.0.20"
CONTAINER1_IPV6="fd00:172:20::10"
CONTAINER2_IPV6="fd00:172:20::20"
# This script deploys 2 VyOS docker containers on the same docker network

set -e  # Exit on any error

# Configuration
NETWORK_NAME="vyos-network"
SUBNET="172.20.0.0/24"
SUBNET_IPV6="fd00:172:20::/64"
VYOS_IMAGE="vyos:1.5"
CONTAINER1_NAME="vyos-router1"
CONTAINER2_NAME="vyos-router2"
CONTAINER1_IP="172.20.0.10"
CONTAINER2_IP="172.20.0.20"
CONTAINER1_IPV6="fd00:172:20::10"
CONTAINER2_IPV6="fd00:172:20::20"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to clean up existing resources
cleanup() {
    log_info "Cleaning up existing resources..."
    
    # Stop and remove containers if they exist
    for container in $CONTAINER1_NAME $CONTAINER2_NAME; do
        if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$"; then
            log_info "Stopping and removing container: $container"
            docker stop $container >/dev/null 2>&1 || true
            docker rm $container >/dev/null 2>&1 || true
        fi
    done
    
    # Remove network if it exists
    if docker network ls --format "table {{.Name}}" | grep -q "^${NETWORK_NAME}$"; then
        log_info "Removing existing network: $NETWORK_NAME"
        docker network rm $NETWORK_NAME >/dev/null 2>&1 || true
    fi
}

# Function to create docker network
create_network() {
    log_info "Creating docker network: $NETWORK_NAME with IPv4 subnet: $SUBNET and IPv6 subnet: $SUBNET_IPV6"
    docker network create \
        --driver bridge \
        --subnet=$SUBNET \
        --ipv6 \
        --subnet=$SUBNET_IPV6 \
        $NETWORK_NAME
}

# Function to wait for containers to be ready
wait_for_containers() {
    log_info "Waiting for containers to be ready..."
    
    for container in $CONTAINER1_NAME $CONTAINER2_NAME; do
        log_info "Waiting for $container to be ready..."
        
        # Wait up to 60 seconds for container to be ready
        for i in {1..60}; do
            if docker exec $container ip addr show eth0 >/dev/null 2>&1; then
                log_info "✓ $container is ready"
                break
            fi
            if [ $i -eq 60 ]; then
                log_error "✗ $container failed to become ready after 60 seconds"
                return 1
            fi
            sleep 1
        done
    done
    
    # Additional wait for network stack to be fully initialized
    log_info "Waiting for network stack initialization..."
    sleep 5
}

# Function to deploy VyOS container
deploy_vyos_container() {
    local container_name=$1
    local ip_address=$2
    local ipv6_address=$3
    
    log_info "Deploying VyOS container: $container_name with IPv4: $ip_address and IPv6: $ipv6_address"
    
    docker run -d \
        --name $container_name \
        --network $NETWORK_NAME \
        --ip $ip_address \
        --ip6 $ipv6_address \
        --privileged \
        --cap-add=NET_ADMIN \
        --sysctl net.ipv4.ip_forward=1 \
        --sysctl net.ipv6.conf.all.forwarding=1 \
        --sysctl net.ipv6.conf.default.forwarding=1 \
        $VYOS_IMAGE \
        /sbin/init
}

# Function to wait for VyOS containers to be ready
wait_for_containers() {
    log_info "Waiting for VyOS containers to be ready..."
    
    for container in $CONTAINER1_NAME $CONTAINER2_NAME; do
        log_info "Waiting for $container to be ready..."
        local max_attempts=30
        local attempt=0
        
        while [ $attempt -lt $max_attempts ]; do
            if docker exec $container vbash --help >/dev/null 2>&1; then
                log_info "✓ $container is ready"
                break
            fi
            
            if [ $attempt -eq $((max_attempts - 1)) ]; then
                log_warn "⚠ $container may not be fully ready, but continuing..."
                break
            fi
            
            sleep 2
            attempt=$((attempt + 1))
        done
    done
}
configure_vyos() {
    local container_name=$1
    local router_id=$2
    
    log_info "Configuring VyOS router: $container_name"
    
    # Wait for container to be ready
    sleep 5
    
    # Basic configuration
    docker exec -it $container_name vbash -c "
        source /opt/vyatta/etc/functions/script-template
        configure
        set system host-name $container_name
        set system domain-name lab.local
        set interfaces ethernet eth0 description 'Management Interface'
        set interfaces ethernet eth0 address dhcp
        set service ssh port 22
        set service ssh disable-password-authentication
        commit
        save
        exit
    "
}

# Function to show container status
show_status() {
    log_info "Container Status:"
    echo "===================="
    docker ps --filter "name=${CONTAINER1_NAME}" --filter "name=${CONTAINER2_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    log_info "Network Information:"
    echo "===================="
    docker network inspect $NETWORK_NAME --format='{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
    echo ""
    
    log_info "Container IPs:"
    echo "===================="
    for container in $CONTAINER1_NAME $CONTAINER2_NAME; do
        ipv4=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container 2>/dev/null || echo "N/A")
        ipv6=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' $container 2>/dev/null || echo "N/A")
        echo "$container: IPv4=$ipv4, IPv6=$ipv6"
    done
}

# Function to test connectivity
test_connectivity() {
    log_info "Testing connectivity between containers..."
    
    # Test IPv4 ping from router1 to router2
    if docker exec $CONTAINER1_NAME ping -c 3 $CONTAINER2_IP >/dev/null 2>&1; then
        log_info "✓ IPv4 connectivity test successful: $CONTAINER1_NAME -> $CONTAINER2_NAME"
    else
        log_error "✗ IPv4 connectivity test failed: $CONTAINER1_NAME -> $CONTAINER2_NAME"
    fi
    
    # Test IPv4 ping from router2 to router1
    if docker exec $CONTAINER2_NAME ping -c 3 $CONTAINER1_IP >/dev/null 2>&1; then
        log_info "✓ IPv4 connectivity test successful: $CONTAINER2_NAME -> $CONTAINER1_NAME"
    else
        log_error "✗ IPv4 connectivity test failed: $CONTAINER2_NAME -> $CONTAINER1_NAME"
    fi
    
    # Test IPv6 ping from router1 to router2
    if docker exec $CONTAINER1_NAME ping6 -c 3 $CONTAINER2_IPV6 >/dev/null 2>&1; then
        log_info "✓ IPv6 connectivity test successful: $CONTAINER1_NAME -> $CONTAINER2_NAME"
    else
        log_error "✗ IPv6 connectivity test failed: $CONTAINER1_NAME -> $CONTAINER2_NAME"
    fi
    
    # Test IPv6 ping from router2 to router1
    if docker exec $CONTAINER2_NAME ping6 -c 3 $CONTAINER1_IPV6 >/dev/null 2>&1; then
        log_info "✓ IPv6 connectivity test successful: $CONTAINER2_NAME -> $CONTAINER1_NAME"
    else
        log_error "✗ IPv6 connectivity test failed: $CONTAINER2_NAME -> $CONTAINER1_NAME"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cleanup     Clean up existing containers and network"
    echo "  --status      Show status of deployed containers"
    echo "  --test        Test connectivity between containers"
    echo "  --help        Show this help message"
    echo ""
    echo "Default behavior: Deploy 2 VyOS containers on the same network"
}

# Main deployment function
deploy() {
    log_info "Starting VyOS docker deployment..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Cleanup existing resources
    cleanup
    
    # Create network
    create_network
  
    # Deploy containers
    deploy_vyos_container $CONTAINER1_NAME $CONTAINER1_IP $CONTAINER1_IPV6
    deploy_vyos_container $CONTAINER2_NAME $CONTAINER2_IP $CONTAINER2_IPV6
    
    # Wait for containers to be ready
    wait_for_containers
    
    # Configure routers (optional - basic config)
    configure_vyos $CONTAINER1_NAME "1"
    configure_vyos $CONTAINER2_NAME "2"
    
    # Show status
    show_status
    
    # Test connectivity
    test_connectivity
    
    log_info "Deployment completed successfully!"
    log_info "You can connect to the containers using:"
    log_info "  docker exec -it $CONTAINER1_NAME vbash"
    log_info "  docker exec -it $CONTAINER2_NAME vbash"
}

# Parse command line arguments
case "${1:-}" in
    --cleanup)
        cleanup
        log_info "Cleanup completed."
        ;;
    --status)
        show_status
        ;;
    --test)
        test_connectivity
        ;;
    --help)
        show_usage
        ;;
    "")
        deploy
        ;;
    *)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac