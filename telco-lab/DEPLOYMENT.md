# Telco Lab Deployment Guide

This guide provides step-by-step instructions for deploying the telco lab network using VyOS routers.

## Prerequisites

### System Requirements
- Docker Engine 20.10+ with Docker Compose
- At least 8GB RAM (16GB recommended)
- 20GB free disk space
- Linux host (Ubuntu 20.04+ recommended)
- Optional: Kubernetes cluster with kubectl configured

### Required Software
```bash
# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Optional: Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

## VyOS Image Preparation

The lab requires a VyOS Docker image. You need to build this manually:

### Method 1: Build from Source (Recommended)
```bash
# Clone VyOS build repository
git clone -b current --single-branch https://github.com/vyos/vyos-build
cd vyos-build

# Build the build environment
docker build -t vyos/vyos-build:current docker

# Build VyOS ISO (this takes 30-60 minutes)
docker run --rm -it --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:current bash
# Inside the container:
sudo ./build-vyos-image --architecture amd64 --version 1.5 generic
exit

# Convert ISO to Docker image
mkdir vyos-docker && cd vyos-docker
mkdir rootfs
sudo mount -o loop ../build/vyos-1.5-generic-amd64.iso rootfs
sudo apt-get install -y squashfs-tools
mkdir unsquashfs
sudo unsquashfs -f -d unsquashfs/ rootfs/live/filesystem.squashfs
sudo tar -C unsquashfs -c . | docker import - vyos:1.5
sudo umount rootfs
cd .. && sudo rm -rf vyos-docker
```

### Method 2: Use Pre-built Image (if available)
```bash
# If you have access to a pre-built VyOS image
docker pull your-registry/vyos:1.5
docker tag your-registry/vyos:1.5 vyos:1.5
```

## Quick Start

### Automated Setup
```bash
# Make setup script executable
chmod +x telco-lab/scripts/setup.sh

# Run the setup script
./telco-lab/scripts/setup.sh
```

The script will:
1. Check prerequisites
2. Verify VyOS image availability
3. Create additional configuration files
4. Deploy the lab environment
5. Run basic connectivity tests
6. Display access information

### Manual Setup

#### 1. Deploy with Docker Compose
```bash
cd telco-lab/docker
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

#### 2. Deploy with Kubernetes (Optional)
```bash
# Apply CRDs
kubectl apply -f operator/config/vyosnetwork.yaml
kubectl apply -f operator/config/vyosrouter.yaml

# Deploy network configuration
kubectl apply -f telco-lab/kubernetes/vyos-network.yaml
kubectl apply -f telco-lab/kubernetes/vyos-routers.yaml

# Check status
kubectl get vyosnetworks,vyosrouters
```

## Network Architecture

### Topology Overview
```
Internet ── External-GW ── PE-1 ── Core-1 ── Core-2 ── PE-2
                           │        │         │        │
                           │        └─────────┘        │
                           │                           │
                        AGG-1                       AGG-2
                           │                           │
                      CPE-1,CPE-3                 CPE-2,CPE-4
```

### IP Addressing
| Component | IP Address | Network | Purpose |
|-----------|------------|---------|---------|
| External-GW | 10.1.0.1/30 | Core Link | Internet simulation |
| PE-1 | 10.0.0.1/32 | Loopback | Router ID |
| PE-2 | 10.0.0.2/32 | Loopback | Router ID |
| Core-1 | 10.0.0.11/32 | Loopback | Router ID |
| Core-2 | 10.0.0.12/32 | Loopback | Router ID |
| AGG-1 | 10.0.0.21/32 | Loopback | Router ID |
| AGG-2 | 10.0.0.22/32 | Loopback | Router ID |
| CPE Network 1 | 10.10.1.0/24 | Access | Customer access |
| CPE Network 2 | 10.10.2.0/24 | Access | Customer access |

## Testing and Verification

### Basic Connectivity Tests
```bash
# Test CPE to CPE connectivity
docker exec cpe-1 ping -c 3 10.10.2.10

# Test internet connectivity
docker exec cpe-1 ping -c 3 8.8.8.8

# Test traceroute through MPLS core
docker exec cpe-1 traceroute 10.10.2.10
```

### Protocol Verification

#### OSPF Status
```bash
# Check OSPF neighbors
docker exec core-1 vtysh -c "show ip ospf neighbor"
docker exec pe-1 vtysh -c "show ip ospf neighbor"

# Check OSPF database
docker exec core-1 vtysh -c "show ip ospf database"

# Check routing table
docker exec core-1 vtysh -c "show ip route"
```

#### BGP Status
```bash
# Check BGP summary
docker exec pe-1 vtysh -c "show ip bgp summary"
docker exec core-1 vtysh -c "show ip bgp summary"

# Check BGP routes
docker exec pe-1 vtysh -c "show ip bgp"

# Check VPN routes
docker exec pe-1 vtysh -c "show ip bgp vpnv4 all"
```

#### MPLS Status
```bash
# Check MPLS forwarding table
docker exec core-1 vtysh -c "show mpls table"
docker exec pe-1 vtysh -c "show mpls table"

# Check LDP neighbors
docker exec core-1 vtysh -c "show mpls ldp neighbor"

# Check LDP bindings
docker exec core-1 vtysh -c "show mpls ldp binding"
```

### Performance Testing

#### Bandwidth Testing with iperf3
```bash
# Start iperf3 server on CPE-2
docker exec -d cpe-2 iperf3 -s

# Run bandwidth test from CPE-1 to CPE-2
docker exec cpe-1 iperf3 -c 10.10.2.10 -t 30

# Test with different traffic classes
docker exec cpe-1 iperf3 -c 10.10.2.10 -t 10 --dscp ef  # Voice
docker exec cpe-1 iperf3 -c 10.10.2.10 -t 10 --dscp af41 # Video
```

#### Latency Testing
```bash
# Measure latency
docker exec cpe-1 ping -c 100 10.10.2.10

# Measure jitter
docker exec cpe-1 ping -c 100 -i 0.1 10.10.2.10
```

## Monitoring and Management

### Access Router CLI
```bash
# Access router configuration mode
docker exec -it core-1 vbash
docker exec -it pe-1 vbash
docker exec -it agg-1 vbash

# Access operational mode
docker exec -it core-1 vtysh
```

### Monitoring Dashboard
- Prometheus: http://localhost:9090
- View metrics for all routers
- Monitor interface utilization
- Track protocol status

### Log Analysis
```bash
# View container logs
docker-compose logs -f core-1
docker-compose logs -f pe-1

# View system logs inside router
docker exec core-1 tail -f /var/log/messages
```

## Troubleshooting

### Common Issues

#### 1. Containers Not Starting
```bash
# Check Docker daemon
sudo systemctl status docker

# Check container logs
docker-compose logs [service-name]

# Restart specific service
docker-compose restart [service-name]
```

#### 2. Routing Issues
```bash
# Check interface status
docker exec core-1 show interfaces

# Check protocol status
docker exec core-1 show protocols

# Restart routing protocols
docker exec core-1 restart routing
```

#### 3. MPLS Issues
```bash
# Check MPLS configuration
docker exec core-1 show mpls

# Verify LDP sessions
docker exec core-1 show mpls ldp session

# Check label bindings
docker exec core-1 show mpls ldp binding
```

#### 4. BGP Issues
```bash
# Check BGP configuration
docker exec pe-1 show protocols bgp

# Reset BGP sessions
docker exec pe-1 reset ip bgp *

# Check BGP logs
docker exec pe-1 show log | grep bgp
```

### Performance Optimization

#### 1. Container Resources
```yaml
# In docker-compose.yml, add resource limits
services:
  core-1:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

#### 2. Network Optimization
```bash
# Enable jumbo frames for core links
docker exec core-1 configure
set interfaces ethernet eth1 mtu 9000
commit
```

## Cleanup

### Stop Lab
```bash
# Stop all containers
cd telco-lab/docker
docker-compose down

# Remove volumes (optional)
docker-compose down -v

# Clean up Kubernetes resources
kubectl delete vyosrouters --all
kubectl delete vyosnetworks --all
```

### Complete Cleanup
```bash
# Remove all lab containers and images
docker system prune -a

# Remove VyOS image
docker rmi vyos:1.5
```

## Advanced Configuration

### Adding Custom Routes
```bash
docker exec pe-1 vbash
configure
set protocols static route 192.168.0.0/16 next-hop 10.1.0.1
commit
save
```

### Configuring QoS Policies
```bash
docker exec agg-1 vbash
configure
set traffic-policy shaper CUSTOMER-QOS bandwidth 50mbit
set traffic-policy shaper CUSTOMER-QOS class 1 bandwidth 20%
set traffic-policy shaper CUSTOMER-QOS class 1 priority 7
commit
```

### Adding VRF Customers
```bash
docker exec pe-1 vbash
configure
set vrf name CUSTOMER-C table 300
set protocols bgp 65001 vrf CUSTOMER-C rd 65001:300
commit
```

## Support and Documentation

- VyOS Documentation: https://docs.vyos.io/
- Docker Compose Reference: https://docs.docker.com/compose/
- Kubernetes Documentation: https://kubernetes.io/docs/
- MPLS/BGP References: RFC 3031, RFC 4364

For issues specific to this lab setup, check the logs and verify the network topology matches the expected configuration.
