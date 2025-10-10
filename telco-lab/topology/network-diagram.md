# Network Topology Details

## Physical Topology

```
                         Internet (0.0.0.0/0)
                                |
                         [External-GW]
                         192.168.1.1/24
                                |
                         10.1.0.0/30
                                |
    ┌───────────────────────────────────────────────────────────────┐
    │                    CORE NETWORK (AS 65001)                    │
    │                                                               │
    │  [PE-1]──────────[Core-1]──────────[Core-2]──────────[PE-2]  │
    │ 10.0.0.1        10.0.0.11       10.0.0.12        10.0.0.2   │
    │    │               │                │               │        │
    │    │10.1.1.0/30    │10.1.2.0/30    │10.1.3.0/30   │        │
    │    │               └────────────────┘               │        │
    │    │                  10.1.4.0/30                  │        │
    └────┼─────────────────────────────────────────────────┼────────┘
         │10.1.10.0/30                          10.1.20.0/30
         │                                                 │
    ┌────┼─────────────────────────────────────────────────┼────────┐
    │    │                ACCESS LAYER                     │        │
    │    │                                                 │        │
    │ [AGG-1]                                           [AGG-2]     │
    │10.0.0.21                                         10.0.0.22   │
    │    │                                                 │        │
    │    │10.10.1.0/24                          10.10.2.0/24       │
    │    │                                                 │        │
    │ ┌──┴──┐                                          ┌──┴──┐     │
    │ │CPE-1│                                          │CPE-2│     │
    │ │.10  │                                          │.10  │     │
    │ └─────┘                                          └─────┘     │
    │ ┌─────┐                                          ┌─────┐     │
    │ │CPE-3│                                          │CPE-4│     │
    │ │.11  │                                          │.11  │     │
    │ └─────┘                                          └─────┘     │
    └───────────────────────────────────────────────────────────────┘
```

## Interface Assignments

### Core-1 (10.0.0.11)
- eth0: 10.1.1.2/30 → PE-1
- eth1: 10.1.2.2/30 → Core-2  
- eth2: 10.1.4.1/30 → Core-2 (backup)
- lo: 10.0.0.11/32

### Core-2 (10.0.0.12)
- eth0: 10.1.2.1/30 → Core-1
- eth1: 10.1.3.2/30 → PE-2
- eth2: 10.1.4.2/30 → Core-1 (backup)
- lo: 10.0.0.12/32

### PE-1 (10.0.0.1)
- eth0: 10.1.0.2/30 → External-GW
- eth1: 10.1.1.1/30 → Core-1
- eth2: 10.1.10.1/30 → AGG-1
- lo: 10.0.0.1/32

### PE-2 (10.0.0.2)
- eth0: 10.1.3.1/30 → Core-2
- eth1: 10.1.20.1/30 → AGG-2
- lo: 10.0.0.2/32

### AGG-1 (10.0.0.21)
- eth0: 10.1.10.2/30 → PE-1
- eth1: 10.10.1.1/24 → CPE subnet
- lo: 10.0.0.21/32

### AGG-2 (10.0.0.22)
- eth0: 10.1.20.2/30 → PE-2
- eth1: 10.10.2.1/24 → CPE subnet
- lo: 10.0.0.22/32

## OSPF Areas
- Area 0 (Backbone): Core-1, Core-2, PE-1, PE-2
- Area 1: AGG-1 and downstream
- Area 2: AGG-2 and downstream

## BGP Configuration
- AS 65001: Internal network
- AS 65000: External/Internet simulation
- Route Reflectors: Core-1, Core-2

## MPLS Labels
- LDP enabled on all core interfaces
- Label range: 16-1048575
- Transport labels for VPN traffic

## VRF Configuration
- VRF-CUSTOMER-A: 172.16.0.0/16 (RD: 65001:100, RT: 100:100)
- VRF-CUSTOMER-B: 172.17.0.0/16 (RD: 65001:200, RT: 200:200)
