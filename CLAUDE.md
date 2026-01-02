# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a P4 programmable network switch implementation targeting **Barefoot Tofino NIC/Switch** architecture. The project implements a sophisticated L2/L3 switch with advanced features including:

- **Flowlet-based load balancing** (primary focus)
- **Clos topology simulation** on single hardware
- L2/L3 switching with VLAN and ARP support
- IPv4/IPv6 routing and ECMP
- Segment Routing (SRv6)

## Project Structure

The repository contains three main implementations:

### `flowlet_v1/` - Full-featured Implementation
The most complete implementation with modular P4 architecture:
- **Controls**: Separate P4 control blocks (`switch_ingress.p4`, `clos_forwarding.p4`, `fib.p4`, etc.)
- **Parsers/Deparsers**: TNA-specific packet processing
- **Advanced Features**: Flowlet switching with 64μs timeout, atomic RegisterActions
- **Control Plane**: Python scripts for table configuration via BFRT API

### `flowlet_v2/` - Minimal TNA-optimized Version
Streamlined implementation focusing on core flowlet functionality:
- **Entry Point**: `tofino/flowlet_tna.p4`
- **Minimalist Design**: Essential components only
- **Chinese Documentation**: Detailed setup guides in Chinese

### `tna_simple_switch_ecmp/` - ECMP-focused Alternative
Alternative implementation emphasizing traditional ECMP over flowlet switching.

## Architecture Key Points

### Clos Topology on Single Switch
The system simulates 4 logical Edge (Leaf) switches on one physical switch:
- **Physical Port Mapping**: Ports 1-8 (hosts), 25-32 (spine uplinks)
- **Edge Assignment**: Each edge gets 2 host ports + 2 spine uplinks
- **IP Planning**: 172.x.1.0/29 subnets per edge, 172.16.x.0/31 P2P links

### Flowlet Load Balancing Algorithm
Advanced traffic engineering using atomic register operations:
- **Flow Tracking**: 5-tuple hash to flow ID (32768 entries)
- **Timeout Detection**: 64μs flowlet boundary detection
- **Path Persistence**: Cached ECMP selection per active flowlet
- **RegisterActions**: `flowlet_last_seen`, `flowlet_counter`, `flowlet_path`

### Modular P4 Design Pattern
- **Separate Concerns**: MAC learning, FIB lookup, LAG, ARP in separate files
- **Control Composition**: Main control instantiates sub-controls
- **Reusable Structures**: Common headers/metadata across modules

## Environment Setup

### Required Environment Variables
```bash
export SDE=/home/asu/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
export LD_LIBRARY_PATH=$SDE_INSTALL/lib:$LD_LIBRARY_PATH
```

## Build and Compilation Commands

### Method 1: p4-build (Recommended)
```bash
cd $SDE/p4-build-9.1.0

# Clear previous builds
make clean 2>/dev/null || true

# Configure for specific implementation
./configure --prefix=$SDE_INSTALL \
    --with-tofino \
    P4_NAME=tna_simple_switch \
    P4_PATH=/home/asu/p4proj/tna_simple_switch/flowlet_v1/tna_simple_switch.p4 \
    P4_VERSION=p4-16 \
    P4_ARCHITECTURE=tna

# Build and install
make && make install
```

### Method 2: Direct bf-p4c Compilation
```bash
# Create output directory
mkdir -p $SDE_INSTALL/share/tofinopd/tna_simple_switch/pipe

# Compile P4 program
bf-p4c --std p4-16 \
    --arch tna \
    --target tofino \
    -o $SDE_INSTALL/share/tofinopd/tna_simple_switch/pipe \
    /path/to/program.p4
```

### Verify Build Artifacts
```bash
ls -la $SDE_INSTALL/share/tofinopd/tna_simple_switch/
# Should contain: bf-rt.json, pipe/context.json, pipe/tofino.bin
```

## Runtime Commands

### Start Switch Daemon
```bash
# Method 1: Using program name
sudo $SDE/run_switchd.sh -p tna_simple_switch

# Method 2: Using BSPless config (recommended)
sudo $SDE/run_switchd.sh -c $SDE_INSTALL/share/p4/targets/tofino/tna_simple_switch-bspless.conf
```

### Port Initialization
```bash
# Bring up ports using provided script
$SDE_INSTALL/bin/bfshell -f /home/asu/p4proj/tna_simple_switch/flowlet_v1/bringUpPorts.cmd

# Or manually in bfshell:
# ucli -> pm -> port-add X/0 100G RS -> an-set X/0 2 -> port-enb X/0
```

### Table Configuration
```bash
# Configure Clos topology (flowlet_v1)
$SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/flowlet_v1/clos_setup.py

# Configure ARP responses
$SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/flowlet_v1/arp_setup.py
```

## Testing Commands

### PTF Tests
```bash
# Run all tests
sudo $SDE/run_p4_tests.sh \
    -p tna_simple_switch \
    -t /home/asu/p4proj/tna_simple_switch/flowlet_v1

# Run specific test class
sudo $SDE/run_p4_tests.sh \
    -p tna_simple_switch \
    -t /home/asu/p4proj/tna_simple_switch/flowlet_v1 \
    -s tests.YourTestClassName
```

### Interactive Debugging
```bash
# Connect to running switch
$SDE/run_bfshell.sh

# Debug Clos forwarding
$SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/flowlet_v1/debug_clos.py

# Check table contents
$SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/tna_simple_switch_ecmp/check_tables.py
```

### Network Testing
```bash
# ARP testing
sudo arping -I <interface> 172.1.1.1 -c 3
sudo tcpdump -i <interface> arp -nn -e

# Traffic generation with Scapy (for flowlet testing)
# Use provided Python scripts in tests.py
```

## Development Workflow

### For P4 Data Plane Changes
1. Edit P4 files in appropriate implementation directory
2. Recompile using p4-build or bf-p4c
3. Restart bf_switchd with new binary
4. Reconfigure tables using Python setup scripts
5. Test with PTF or manual traffic injection

### For Control Plane Changes
1. Modify Python configuration scripts (`*_setup.py`)
2. Run updated script via bfshell: `$SDE/run_bfshell.sh -b script.py`
3. Verify table contents in bfshell interactive mode

### Key Files to Modify

**P4 Data Plane (flowlet_v1):**
- `controls/clos_forwarding.p4` - Core Clos and flowlet logic
- `controls/switch_ingress.p4` - Main ingress pipeline
- `metadata.p4` - Constants and data structures
- `headers.p4` - Protocol definitions

**Control Plane:**
- `clos_setup.py` - Topology and ECMP configuration
- `arp_setup.py` - ARP table population
- `debug_clos.py` - Debugging and inspection

## Hardware-Specific Notes

### Tofino Architecture
- **Target Hardware**: Barefoot Tofino ASIC (Wedge100BF-32X or similar)
- **Pipeline Configuration**: Uses all 4 available pipelines
- **Port Mapping**: 100G ports for hosts, 40G ports for spine uplinks
- **BSPless Mode**: Direct hardware access without Board Support Package

### Register Usage (flowlet_v1)
- **flowlet_last_seen**: 32768 entries, packet timestamps
- **flowlet_counter**: 32768 entries, flowlet ID generation
- **flowlet_path**: 32768 entries, cached ECMP path selection
- All register operations use RegisterAction for atomicity

### Performance Considerations
- **Flowlet Timeout**: 64μs (configurable in metadata.p4)
- **Hash Fields**: 5-tuple (src/dst IP, protocol, src/dst port)
- **Table Sizes**: Configured for production workloads (1K+ entries)
- **ECMP Groups**: Support for 2-4 way load balancing per destination

## Troubleshooting

### Common Issues
- **Compilation Failures**: Check bf-p4c version and P4 syntax
- **switchd Startup**: Verify hugepages and root permissions
- **Port Issues**: Ensure physical connections and bringUpPorts.cmd execution
- **Table Misses**: Run appropriate setup scripts before traffic injection
- **Flowlet Behavior**: Use debug scripts to inspect register state


## 补充

你当前处于的环境是Ubuntu开发机，只要编译成功即可。
编译所需命令：
```

export SDE=/home/asu/Desktop/bf-sde-9.1.0 && export SDE_INSTALL=$SDE/install && export PATH=$PATH:$SDE_INSTALL/bin && P4_PATH="/home/asu/Desktop/p4proj/tna_simple_switch/flowlet_v2/tofino/flowlet_tna.p4" && cd /tmp && mkdir -p p4_build && cd p4_build && bf-p4c -a tna -b tofino "$P4_PATH"


export SDE=/home/asu/Desktop/bf-sde-9.1.0 && export SDE_INSTALL=$SDE/install && export PATH=$PATH:$SDE_INSTALL/bin && P4_PATH="/home/asu/Desktop/p4proj/tna_simple_switch/flowlet_v2/tofino/flowlet_tna.p4" && cd /tmp && mkdir -p p4_build && cd p4_build && bf-p4c -a tna -b tofino "$P4_PATH"


```