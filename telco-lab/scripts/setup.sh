#!/bin/bash

# Telco Lab Setup Script
# This script sets up the complete telco lab environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    # Check if kubectl is installed (for Kubernetes deployment)
    if command -v kubectl &> /dev/null; then
        info "kubectl found - Kubernetes deployment will be available"
    else
        warn "kubectl not found - Kubernetes deployment will be skipped"
    fi
    
    log "Prerequisites check completed successfully"
}

# Build VyOS image if it doesn't exist
build_vyos_image() {
    log "Checking VyOS image..."
    
    if docker images | grep -q "vyos.*1.5"; then
        info "VyOS image already exists"
        return 0
    fi
    
    warn "VyOS image not found. You need to build it manually."
    echo ""
    echo "To build the VyOS image, follow these steps:"
    echo "1. Clone VyOS build repository:"
    echo "   git clone -b current --single-branch https://github.com/vyos/vyos-build"
    echo "2. Build the ISO:"
    echo "   cd vyos-build"
    echo "   docker build -t vyos/vyos-build:current docker"
    echo "   docker run --rm -it --privileged -v \$(pwd):/vyos -w /vyos vyos/vyos-build:current bash"
    echo "   sudo ./build-vyos-image --architecture amd64 --version 1.5 generic"
    echo "3. Create Docker image:"
    echo "   mkdir vyos && cd vyos"
    echo "   mkdir rootfs"
    echo "   sudo mount -o loop ../build/vyos-1.5-generic-amd64.iso rootfs"
    echo "   sudo apt-get install -y squashfs-tools"
    echo "   mkdir unsquashfs"
    echo "   sudo unsquashfs -f -d unsquashfs/ rootfs/live/filesystem.squashfs"
    echo "   sudo tar -C unsquashfs -c . | docker import - vyos:1.5"
    echo ""
    read -p "Press Enter when you have built the VyOS image, or Ctrl+C to exit..."
}

# Create additional configuration files
create_additional_configs() {
    log "Creating additional configuration files..."
    
    # Create external gateway config
    cat > telco-lab/configs/external-gw.conf << 'EOF'
#!/bin/vbash
# External Gateway Configuration (Internet Simulation)

set system host-name 'external-gw'
set system domain-name 'internet.sim'

# Configure interfaces
set interfaces ethernet eth0 address '192.168.1.1/24'
set interfaces ethernet eth0 description 'External Internet'
set interfaces ethernet eth1 address '10.1.0.1/30'
set interfaces ethernet eth1 description 'Link to PE-1'
set interfaces loopback lo address '8.8.8.8/32'

# BGP Configuration
set protocols bgp 65000 router-id '10.1.0.1'
set protocols bgp 65000 neighbor 10.1.0.2 remote-as '65001'
set protocols bgp 65000 neighbor 10.1.0.2 description 'PE-1'
set protocols bgp 65000 address-family ipv4-unicast network '0.0.0.0/0'
set protocols bgp 65000 address-family ipv4-unicast network '8.8.8.8/32'

# Static routes
set protocols static route 0.0.0.0/0 next-hop 192.168.1.254

# NAT for internet simulation
set nat source rule 100 outbound-interface 'eth0'
set nat source rule 100 source address '10.0.0.0/8'
set nat source rule 100 translation address 'masquerade'

commit
save
EOF

    # Create Core-2 config
    cat > telco-lab/configs/core-2.conf << 'EOF'
#!/bin/vbash
# VyOS Configuration for Core-2 Router
# Role: MPLS P Router (Provider Core)

set system host-name 'core-2'
set system domain-name 'telco.lab'
set system time-zone 'UTC'

# Configure loopback interface (Router ID)
set interfaces loopback lo address '10.0.0.12/32'
set interfaces loopback lo description 'Router ID and MPLS LSR-ID'

# Interface to Core-1 (primary)
set interfaces ethernet eth0 address '10.1.2.1/30'
set interfaces ethernet eth0 description 'Link to Core-1 Primary'
set interfaces ethernet eth0 mtu '9000'

# Interface to PE-2
set interfaces ethernet eth1 address '10.1.3.2/30'
set interfaces ethernet eth1 description 'Link to PE-2'
set interfaces ethernet eth1 mtu '9000'

# Interface to Core-1 (backup)
set interfaces ethernet eth2 address '10.1.4.2/30'
set interfaces ethernet eth2 description 'Link to Core-1 Backup'
set interfaces ethernet eth2 mtu '9000'

# OSPF Configuration
set protocols ospf area 0 network '10.0.0.12/32'
set protocols ospf area 0 network '10.1.2.0/30'
set protocols ospf area 0 network '10.1.3.0/30'
set protocols ospf area 0 network '10.1.4.0/30'
set protocols ospf router-id '10.0.0.12'
set protocols ospf log-adjacency-changes

# MPLS Configuration
set protocols mpls interface eth0
set protocols mpls interface eth1
set protocols mpls interface eth2
set protocols mpls ldp router-id '10.0.0.12'
set protocols mpls ldp interface eth0
set protocols mpls ldp interface eth1
set protocols mpls ldp interface eth2

# BGP Configuration (Route Reflector)
set protocols bgp 65001 router-id '10.0.0.12'
set protocols bgp 65001 neighbor 10.0.0.1 remote-as '65001'
set protocols bgp 65001 neighbor 10.0.0.1 update-source 'loopback'
set protocols bgp 65001 neighbor 10.0.0.1 route-reflector-client
set protocols bgp 65001 neighbor 10.0.0.2 remote-as '65001'
set protocols bgp 65001 neighbor 10.0.0.2 update-source 'loopback'
set protocols bgp 65001 neighbor 10.0.0.2 route-reflector-client
set protocols bgp 65001 neighbor 10.0.0.11 remote-as '65001'
set protocols bgp 65001 neighbor 10.0.0.11 update-source 'loopback'

commit
save
EOF

    # Create PE-2 config
    cat > telco-lab/configs/pe-2.conf << 'EOF'
#!/bin/vbash
# VyOS Configuration for PE-2 Router

set system host-name 'pe-2'
set system domain-name 'telco.lab'
set system time-zone 'UTC'

# Configure loopback interface
set interfaces loopback lo address '10.0.0.2/32'
set interfaces loopback lo description 'Router ID and MPLS LSR-ID'

# Interface to Core-2
set interfaces ethernet eth0 address '10.1.3.1/30'
set interfaces ethernet eth0 description 'Link to Core-2'
set interfaces ethernet eth0 mtu '9000'

# Interface to AGG-2
set interfaces ethernet eth1 address '10.1.20.1/30'
set interfaces ethernet eth1 description 'Link to AGG-2'
set interfaces ethernet eth1 mtu '1500'

# OSPF Configuration
set protocols ospf area 0 network '10.0.0.2/32'
set protocols ospf area 0 network '10.1.3.0/30'
set protocols ospf area 2 network '10.1.20.0/30'
set protocols ospf router-id '10.0.0.2'

# MPLS Configuration
set protocols mpls interface eth0
set protocols mpls ldp router-id '10.0.0.2'
set protocols mpls ldp interface eth0

# BGP Configuration
set protocols bgp 65001 router-id '10.0.0.2'
set protocols bgp 65001 neighbor 10.0.0.11 remote-as '65001'
set protocols bgp 65001 neighbor 10.0.0.11 update-source 'loopback'
set protocols bgp 65001 neighbor 10.0.0.12 remote-as '65001'
set protocols bgp 65001 neighbor 10.0.0.12 update-source 'loopback'

commit
save
EOF

    # Create AGG-2 config
    cat > telco-lab/configs/agg-2.conf << 'EOF'
#!/bin/vbash
# VyOS Configuration for AGG-2 Router

set system host-name 'agg-2'
set system domain-name 'telco.lab'
set system time-zone 'UTC'

# Configure loopback interface
set interfaces loopback lo address '10.0.0.22/32'
set interfaces loopback lo description 'Router ID'

# Interface to PE-2
set interfaces ethernet eth0 address '10.1.20.2/30'
set interfaces ethernet eth0 description 'Link to PE-2'
set interfaces ethernet eth0 mtu '1500'

# Interface to CPE subnet
set interfaces ethernet eth1 address '10.10.2.1/24'
set interfaces ethernet eth1 description 'CPE Access Network'
set interfaces ethernet eth1 mtu '1500'

# OSPF Configuration
set protocols ospf area 2 network '10.0.0.22/32'
set protocols ospf area 2 network '10.1.20.0/30'
set protocols ospf area 2 network '10.10.2.0/24'
set protocols ospf router-id '10.0.0.22'

# DHCP Server
set service dhcp-server shared-network-name CPE-NETWORK subnet 10.10.2.0/24 default-router '10.10.2.1'
set service dhcp-server shared-network-name CPE-NETWORK subnet 10.10.2.0/24 dns-server '8.8.8.8'
set service dhcp-server shared-network-name CPE-NETWORK subnet 10.10.2.0/24 range CPE-POOL start '10.10.2.10'
set service dhcp-server shared-network-name CPE-NETWORK subnet 10.10.2.0/24 range CPE-POOL stop '10.10.2.100'

commit
save
EOF

    # Create monitoring configuration
    mkdir -p telco-lab/monitoring
    cat > telco-lab/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'vyos-routers'
    static_configs:
      - targets: 
        - 'core-1:161'
        - 'core-2:161'
        - 'pe-1:161'
        - 'pe-2:161'
        - 'agg-1:161'
        - 'agg-2:161'
    metrics_path: /snmp
    params:
      module: [if_mib]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: snmp-exporter:9116
EOF

    log "Additional configuration files created successfully"
}

# Deploy with Docker Compose
deploy_docker() {
    log "Deploying telco lab with Docker Compose..."
    
    cd telco-lab/docker
    
    # Pull required images
    info "Pulling required images..."
    docker-compose pull monitoring
    
    # Start the lab
    info "Starting telco lab containers..."
    docker-compose up -d
    
    # Wait for containers to be ready
    info "Waiting for containers to initialize..."
    sleep 30
    
    # Check container status
    log "Container status:"
    docker-compose ps
    
    cd ../..
}

# Deploy with Kubernetes
deploy_kubernetes() {
    if ! command -v kubectl &> /dev/null; then
        warn "kubectl not found, skipping Kubernetes deployment"
        return 0
    fi
    
    log "Deploying telco lab with Kubernetes..."
    
    # Apply CRDs
    info "Applying Custom Resource Definitions..."
    kubectl apply -f operator/config/vyosnetwork.yaml
    kubectl apply -f operator/config/vyosrouter.yaml
    
    # Apply network configuration
    info "Applying network configuration..."
    kubectl apply -f telco-lab/kubernetes/vyos-network.yaml
    
    # Apply router configurations
    info "Applying router configurations..."
    kubectl apply -f telco-lab/kubernetes/vyos-routers.yaml
    
    # Check deployment status
    log "Checking deployment status..."
    kubectl get vyosnetworks
    kubectl get vyosrouters
}

# Run tests
run_tests() {
    log "Running basic connectivity tests..."
    
    # Test 1: Ping between CPE devices
    info "Test 1: CPE-1 to CPE-2 connectivity (should work through core)"
    docker exec cpe-1 ping -c 3 10.10.2.10 || warn "CPE-1 to CPE-2 ping failed"
    
    # Test 2: Internet connectivity
    info "Test 2: CPE-1 internet connectivity"
    docker exec cpe-1 ping -c 3 8.8.8.8 || warn "CPE-1 internet connectivity failed"
    
    # Test 3: OSPF neighbor status
    info "Test 3: Checking OSPF neighbors on Core-1"
    docker exec core-1 vtysh -c "show ip ospf neighbor" || warn "OSPF neighbor check failed"
    
    # Test 4: BGP status
    info "Test 4: Checking BGP status on PE-1"
    docker exec pe-1 vtysh -c "show ip bgp summary" || warn "BGP status check failed"
    
    # Test 5: MPLS forwarding table
    info "Test 5: Checking MPLS forwarding table on Core-1"
    docker exec core-1 vtysh -c "show mpls table" || warn "MPLS table check failed"
    
    log "Basic tests completed"
}

# Show lab information
show_info() {
    log "Telco Lab Information"
    echo ""
    echo "=== Network Access ==="
    echo "Monitoring Dashboard: http://localhost:9090"
    echo ""
    echo "=== Router Access ==="
    echo "Core-1:  docker exec -it core-1 vbash"
    echo "Core-2:  docker exec -it core-2 vbash"
    echo "PE-1:    docker exec -it pe-1 vbash"
    echo "PE-2:    docker exec -it pe-2 vbash"
    echo "AGG-1:   docker exec -it agg-1 vbash"
    echo "AGG-2:   docker exec -it agg-2 vbash"
    echo ""
    echo "=== CPE Access ==="
    echo "CPE-1:   docker exec -it cpe-1 sh"
    echo "CPE-2:   docker exec -it cpe-2 sh"
    echo "CPE-3:   docker exec -it cpe-3 sh"
    echo "CPE-4:   docker exec -it cpe-4 sh"
    echo ""
    echo "=== Useful Commands ==="
    echo "View logs:           docker-compose logs -f [service-name]"
    echo "Restart service:     docker-compose restart [service-name]"
    echo "Stop lab:            docker-compose down"
    echo "Clean up:            docker-compose down -v"
    echo ""
}

# Main execution
main() {
    log "Starting Telco Lab Setup"
    
    check_prerequisites
    build_vyos_image
    create_additional_configs
    
    # Choose deployment method
    echo ""
    echo "Choose deployment method:"
    echo "1) Docker Compose (recommended)"
    echo "2) Kubernetes"
    echo "3) Both"
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            deploy_docker
            ;;
        2)
            deploy_kubernetes
            ;;
        3)
            deploy_docker
            deploy_kubernetes
            ;;
        *)
            error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Run tests if Docker deployment was chosen
    if [[ $choice == "1" || $choice == "3" ]]; then
        echo ""
        read -p "Run basic connectivity tests? (y/n): " run_test
        if [[ $run_test == "y" || $run_test == "Y" ]]; then
            run_tests
        fi
    fi
    
    show_info
    log "Telco Lab setup completed successfully!"
}

# Run main function
main "$@"
