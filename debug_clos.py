#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
调试脚本：检查 Clos 拓扑的 P4 表项配置
使用方法: $SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/debug_clos.py

注意：此脚本需要在 bfrt_python 环境中运行，bfrt 会自动可用
"""

print("="*60)
print("Checking Clos Topology P4 Table Entries")
print("="*60)

p4 = bfrt.tna_simple_switch.pipe
clos = p4.SwitchIngress.clos

# 1. 检查 port_to_edge 表
print("\n1. port_to_edge table:")
try:
    port_to_edge = clos.port_to_edge
    port_to_edge.dump(table=True)
except Exception as e:
    print("  Error: {}".format(e))

# 2. 检查 dst_to_edge 表
print("\n2. dst_to_edge table:")
try:
    dst_to_edge = clos.dst_to_edge
    dst_to_edge.dump(table=True)
except Exception as e:
    print("  Error: {}".format(e))

# 3. 检查 local_forward 表
print("\n3. local_forward table:")
try:
    local_forward = clos.local_forward
    local_forward.dump(table=True)
except Exception as e:
    print("  Error: {}".format(e))

# 4. 检查 ecmp_uplink 表
print("\n4. ecmp_uplink table:")
try:
    ecmp_uplink = clos.ecmp_uplink
    ecmp_uplink.dump(table=True)
except Exception as e:
    print("  Error: {}".format(e))

# 5. 检查 ECMP selector groups
print("\n5. ECMP selector groups:")
try:
    ecmp_sel_grp = clos.clos_ecmp_selector_sel
    ecmp_sel_grp.dump(table=True)
except Exception as e:
    print("  Error: {}".format(e))

# 6. 检查 ECMP selector members
print("\n6. ECMP selector members:")
try:
    ecmp_selector = clos.clos_ecmp_selector
    ecmp_selector.dump(table=True)
except Exception as e:
    print("  Error: {}".format(e))

print("\n" + "="*60)
print("Debug check completed")
print("="*60)

