# Telco Lab Network - VyOS Implementation

This lab demonstrates a realistic telco network topology using VyOS routers with IP Core and access layers.

## Network Architecture

```
                    Internet/External
                           |
                    [External Gateway]
                           |
    ┌─────────────────────────────────────────────────────────┐
    │                  CORE NETWORK                           │
    │                                                         │
    │  [PE-1]────────[Core-1]────────[Core-2]────────[PE-2]  │
    │    │              │              │              │      │
    │    │              └──────────────┘              │      │
    │    │                                            │      │
    └────┼────────────────────────────────────────────┼──────┘
         │                                            │
    ┌────┼────────────────────────────────────────────┼──────┐
    │    │              ACCESS LAYER                  │      │
    │    │                                            │      │
    │ [AGG-1]                                      [AGG-2]   │
    │    │                                            │      │
    │ [CPE-1]                                      [CPE-2]   │
    │ [CPE-3]                                      [CPE-4]   │
    └─────────────────────────────────────────────────────────┘
```

## Router Functions

- **Core-1/Core-2**: MPLS P routers running OSPF, providing high-speed backbone
- **PE-1/PE-2**: Provider Edge routers with BGP, MPLS VPN capabilities
- **AGG-1/AGG-2**: Access aggregation routers
- **CPE-1-4**: Customer premises equipment simulation

## Key Features

- OSPF as IGP in core network
- BGP for external connectivity and MPLS L3VPN
- MPLS with LDP for label distribution
- QoS traffic shaping and classification
- Redundant core paths for high availability
- Customer VRF separation

## IP Addressing Scheme

| Network Segment | IP Range | Purpose |
|----------------|----------|---------|
| Core Loopbacks | 10.0.0.0/24 | Router IDs and MPLS |
| Core P2P Links | 10.1.0.0/16 | Backbone connectivity |
| Access Networks | 10.10.0.0/16 | Access aggregation |
| Customer VRF-A | 172.16.0.0/16 | Customer A networks |
| Customer VRF-B | 172.17.0.0/16 | Customer B networks |
| Management | 192.168.100.0/24 | Out-of-band management |

## Files Structure

- `topology/` - Network diagrams and documentation
- `configs/` - VyOS router configurations
- `kubernetes/` - K8s CRD manifests
- `docker/` - Docker network setup
- `scripts/` - Automation and testing scripts
