#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Clos Topology Configuration for tna_simple_switch
使用方法: $SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/clos_setup.py
"""

# =============================================================================
# 获取表引用
# =============================================================================
p4 = bfrt.tna_simple_switch.pipe
clos = p4.SwitchIngress.clos

port_to_edge_table = clos.port_to_edge
dst_to_edge_table = clos.dst_to_edge
local_forward_table = clos.local_forward
flowlet_uplink_table = clos.flowlet_uplink  # 改为flowlet表
saved_path_uplink_table = clos.saved_path_uplink  # 添加保存路径表
arp_table = p4.SwitchIngress.arp_reply_table

# =============================================================================
# 清空表
# =============================================================================
print("\n" + "="*60)
print("  Clos Topology Setup for tna_simple_switch")
print("="*60 + "\n")

# ActionSelector 表引用（需要先获取才能清空）
flowlet_ecmp_selector = clos.flowlet_ecmp_selector  # 改为flowlet selector
flowlet_ecmp_sel_grp = clos.flowlet_ecmp_selector_sel  # 改为flowlet selector group

print("Clearing tables...")
try:
    flowlet_uplink_table.clear()  # 改为flowlet表
    saved_path_uplink_table.clear()  # 添加保存路径表清空
    flowlet_ecmp_sel_grp.clear()  # 改为flowlet selector group
    flowlet_ecmp_selector.clear()  # 改为flowlet selector
    port_to_edge_table.clear()
    dst_to_edge_table.clear()
    local_forward_table.clear()
    arp_table.clear()
except:
    pass
print("Tables cleared.\n")

# =============================================================================
# 配置 port_to_edge 表
# =============================================================================
print("="*60)
print("Configuring port_to_edge table")
print("="*60)

# 端口类型常量
PORT_TYPE_DOWNLINK = 1
PORT_TYPE_UPLINK = 2

# DEV_PORT 映射 (从 pm show 获取)
# 前面板端口 -> DEV_PORT
DEV_PORT = {
    1: 128, 2: 136, 3: 144, 4: 152,   # 下行端口 (Edge 1, 2)
    5: 160, 6: 168, 7: 176, 8: 184,   # 下行端口 (Edge 3, 4)
    25: 188, 26: 180, 27: 172, 28: 164,  # 上行端口 (部分)
    29: 148, 30: 156, 31: 132, 32: 140   # 上行端口 (部分)
}

# Edge 1: 下行 1,2  上行 25,26
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[1], edge_id=1, ptype=PORT_TYPE_DOWNLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[2], edge_id=1, ptype=PORT_TYPE_DOWNLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[25], edge_id=1, ptype=PORT_TYPE_UPLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[26], edge_id=1, ptype=PORT_TYPE_UPLINK)
print("  Edge 1: P1,P2 (down), P25,P26 (up)")

# Edge 2: 下行 3,4  上行 27,28
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[3], edge_id=2, ptype=PORT_TYPE_DOWNLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[4], edge_id=2, ptype=PORT_TYPE_DOWNLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[27], edge_id=2, ptype=PORT_TYPE_UPLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[28], edge_id=2, ptype=PORT_TYPE_UPLINK)
print("  Edge 2: P3,P4 (down), P27,P28 (up)")

# Edge 3: 下行 5,6  上行 29,30
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[5] if 5 in DEV_PORT else 5, edge_id=3, ptype=PORT_TYPE_DOWNLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[6] if 6 in DEV_PORT else 6, edge_id=3, ptype=PORT_TYPE_DOWNLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[29], edge_id=3, ptype=PORT_TYPE_UPLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[30], edge_id=3, ptype=PORT_TYPE_UPLINK)
print("  Edge 3: P5,P6 (down), P29,P30 (up)")

# Edge 4: 下行 7,8  上行 31,32
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[7] if 7 in DEV_PORT else 7, edge_id=4, ptype=PORT_TYPE_DOWNLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[8] if 8 in DEV_PORT else 8, edge_id=4, ptype=PORT_TYPE_DOWNLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[31], edge_id=4, ptype=PORT_TYPE_UPLINK)
port_to_edge_table.add_with_set_port_info(ingress_port=DEV_PORT[32], edge_id=4, ptype=PORT_TYPE_UPLINK)
print("  Edge 4: P7,P8 (down), P31,P32 (up)")

print("")

# =============================================================================
# 配置 dst_to_edge 表 (LPM)
# =============================================================================
print("="*60)
print("Configuring dst_to_edge table (LPM)")
print("="*60)

dst_to_edge_table.add_with_set_dst_edge(dst_addr=0xAC010100, dst_addr_p_length=29, edge_id=1)  # 172.1.1.0/29
dst_to_edge_table.add_with_set_dst_edge(dst_addr=0xAC020100, dst_addr_p_length=29, edge_id=2)  # 172.2.1.0/29
dst_to_edge_table.add_with_set_dst_edge(dst_addr=0xAC030100, dst_addr_p_length=29, edge_id=3)  # 172.3.1.0/29
dst_to_edge_table.add_with_set_dst_edge(dst_addr=0xAC040100, dst_addr_p_length=29, edge_id=4)  # 172.4.1.0/29

print("  172.1.1.0/29 -> Edge 1")
print("  172.2.1.0/29 -> Edge 2")
print("  172.3.1.0/29 -> Edge 3")
print("  172.4.1.0/29 -> Edge 4")
print("")

# =============================================================================
# 配置 local_forward 表
# =============================================================================
print("="*60)
print("Configuring local_forward table")
print("="*60)

# Edge MAC 地址
EDGE1_MAC = 0x001111110001
EDGE2_MAC = 0x001111110002
EDGE3_MAC = 0x001111110003
EDGE4_MAC = 0x001111110004

# 主机 MAC 地址 (从 setup_intf.sh 获取)
H1_MAC = 0xb8cef6fd0f48  # 172.1.1.2
H2_MAC = 0xb8cef6fc567e  # 172.1.1.3
H3_MAC = 0xb8cef6f8c87a  # 172.2.1.2
H4_MAC = 0xb8cef6fd1088  # 172.2.1.3
H5_MAC = 0xb49691d4fab0  # 172.3.1.2
H6_MAC = 0xb49691d4fab1  # 172.3.1.3
H7_MAC = 0xb49691af45b8  # 172.4.1.2
H8_MAC = 0xb49691af45b9  # 172.4.1.3

# Edge 1 主机
local_forward_table.add_with_forward_local(dst_addr=0xAC010102, dst_addr_p_length=32, port=DEV_PORT[1], dst_mac=H1_MAC, src_mac=EDGE1_MAC)  # 172.1.1.2
local_forward_table.add_with_forward_local(dst_addr=0xAC010103, dst_addr_p_length=32, port=DEV_PORT[2], dst_mac=H2_MAC, src_mac=EDGE1_MAC)  # 172.1.1.3
print("  172.1.1.2 -> P1 (DEV_PORT %d), 172.1.1.3 -> P2 (DEV_PORT %d)" % (DEV_PORT[1], DEV_PORT[2]))

# Edge 2 主机
local_forward_table.add_with_forward_local(dst_addr=0xAC020102, dst_addr_p_length=32, port=DEV_PORT[3], dst_mac=H3_MAC, src_mac=EDGE2_MAC)  # 172.2.1.2
local_forward_table.add_with_forward_local(dst_addr=0xAC020103, dst_addr_p_length=32, port=DEV_PORT[4], dst_mac=H4_MAC, src_mac=EDGE2_MAC)  # 172.2.1.3
print("  172.2.1.2 -> P3 (DEV_PORT %d), 172.2.1.3 -> P4 (DEV_PORT %d)" % (DEV_PORT[3], DEV_PORT[4]))

# Edge 3 主机
local_forward_table.add_with_forward_local(dst_addr=0xAC030102, dst_addr_p_length=32, port=DEV_PORT[5], dst_mac=H5_MAC, src_mac=EDGE3_MAC)  # 172.3.1.2
local_forward_table.add_with_forward_local(dst_addr=0xAC030103, dst_addr_p_length=32, port=DEV_PORT[6], dst_mac=H6_MAC, src_mac=EDGE3_MAC)  # 172.3.1.3
print("  172.3.1.2 -> P5 (DEV_PORT %d), 172.3.1.3 -> P6 (DEV_PORT %d)" % (DEV_PORT[5], DEV_PORT[6]))

# Edge 4 主机
local_forward_table.add_with_forward_local(dst_addr=0xAC040102, dst_addr_p_length=32, port=DEV_PORT[7], dst_mac=H7_MAC, src_mac=EDGE4_MAC)  # 172.4.1.2
local_forward_table.add_with_forward_local(dst_addr=0xAC040103, dst_addr_p_length=32, port=DEV_PORT[8], dst_mac=H8_MAC, src_mac=EDGE4_MAC)  # 172.4.1.3
print("  172.4.1.2 -> P7 (DEV_PORT %d), 172.4.1.3 -> P8 (DEV_PORT %d)" % (DEV_PORT[7], DEV_PORT[8]))

print("")

# =============================================================================
# 配置 ARP 表
# =============================================================================
print("="*60)
print("Configuring ARP reply table")
print("="*60)

# Edge 网关 IP + Proxy ARP for all hosts
# Edge 1: 172.1.1.1 (GW), 172.1.1.2 (h1), 172.1.1.3 (h2)
arp_table.add_with_do_arp_reply(tpa=0xAC010101, my_mac=EDGE1_MAC)
arp_table.add_with_do_arp_reply(tpa=0xAC010102, my_mac=EDGE1_MAC)
arp_table.add_with_do_arp_reply(tpa=0xAC010103, my_mac=EDGE1_MAC)

# Edge 2: 172.2.1.1 (GW), 172.2.1.2 (h3), 172.2.1.3 (h4)
arp_table.add_with_do_arp_reply(tpa=0xAC020101, my_mac=EDGE2_MAC)
arp_table.add_with_do_arp_reply(tpa=0xAC020102, my_mac=EDGE2_MAC)
arp_table.add_with_do_arp_reply(tpa=0xAC020103, my_mac=EDGE2_MAC)

# Edge 3: 172.3.1.1 (GW), 172.3.1.2 (h5), 172.3.1.3 (h6)
arp_table.add_with_do_arp_reply(tpa=0xAC030101, my_mac=EDGE3_MAC)
arp_table.add_with_do_arp_reply(tpa=0xAC030102, my_mac=EDGE3_MAC)
arp_table.add_with_do_arp_reply(tpa=0xAC030103, my_mac=EDGE3_MAC)

# Edge 4: 172.4.1.1 (GW), 172.4.1.2 (h7), 172.4.1.3 (h8)
arp_table.add_with_do_arp_reply(tpa=0xAC040101, my_mac=EDGE4_MAC)
arp_table.add_with_do_arp_reply(tpa=0xAC040102, my_mac=EDGE4_MAC)
arp_table.add_with_do_arp_reply(tpa=0xAC040103, my_mac=EDGE4_MAC)

# Underlay Proxy ARP for Spine next-hops (172.16.x.0 and 172.16.x.2)

# Edge 1 underlay
arp_table.add_with_do_arp_reply(tpa=0xAC100100, my_mac=EDGE1_MAC)  # 172.16.1.0
arp_table.add_with_do_arp_reply(tpa=0xAC100102, my_mac=EDGE1_MAC)  # 172.16.1.2

# Edge 2 underlay
arp_table.add_with_do_arp_reply(tpa=0xAC100200, my_mac=EDGE2_MAC)  # 172.16.2.0
arp_table.add_with_do_arp_reply(tpa=0xAC100202, my_mac=EDGE2_MAC)  # 172.16.2.2

# Edge 3 underlay
arp_table.add_with_do_arp_reply(tpa=0xAC100300, my_mac=EDGE3_MAC)  # 172.16.3.0
arp_table.add_with_do_arp_reply(tpa=0xAC100302, my_mac=EDGE3_MAC)  # 172.16.3.2

# Edge 4 underlay
arp_table.add_with_do_arp_reply(tpa=0xAC100400, my_mac=EDGE4_MAC)  # 172.16.4.0
arp_table.add_with_do_arp_reply(tpa=0xAC100402, my_mac=EDGE4_MAC)  # 172.16.4.2

print("  Proxy ARP enabled for all hosts (172.x.1.1-3)")

print("")

# =============================================================================
# 配置 Flowlet 上行表 (ActionSelector)
# =============================================================================
print("="*60)
print("Configuring Flowlet uplink table (ActionSelector)")
print("="*60)

# Spine MAC 地址
SPINE1_MAC = 0x0090fb64cd44
SPINE2_MAC = 0x0090fb64cd44

# SPINE2_MAC = 0x0090fb64cd44

# Step 1: 创建 members (每个上行端口一个 member)
print("Step 1: Creating Flowlet ECMP members...")

# Edge 1 members: P25 (Spine1), P26 (Spine2)
flowlet_ecmp_selector.add_with_set_uplink(action_member_id=11, port=DEV_PORT[25], spine_mac=SPINE1_MAC, edge_mac=EDGE1_MAC)
flowlet_ecmp_selector.add_with_set_uplink(action_member_id=12, port=DEV_PORT[26], spine_mac=SPINE2_MAC, edge_mac=EDGE1_MAC)
print("  Edge 1: member 11 (P25->%d), member 12 (P26->%d)" % (DEV_PORT[25], DEV_PORT[26]))

# Edge 2 members: P27 (Spine1), P28 (Spine2)
flowlet_ecmp_selector.add_with_set_uplink(action_member_id=21, port=DEV_PORT[27], spine_mac=SPINE1_MAC, edge_mac=EDGE2_MAC)
flowlet_ecmp_selector.add_with_set_uplink(action_member_id=22, port=DEV_PORT[28], spine_mac=SPINE2_MAC, edge_mac=EDGE2_MAC)
print("  Edge 2: member 21 (P27->%d), member 22 (P28->%d)" % (DEV_PORT[27], DEV_PORT[28]))

# Edge 3 members: P29 (Spine1), P30 (Spine2)
flowlet_ecmp_selector.add_with_set_uplink(action_member_id=31, port=DEV_PORT[29], spine_mac=SPINE1_MAC, edge_mac=EDGE3_MAC)
flowlet_ecmp_selector.add_with_set_uplink(action_member_id=32, port=DEV_PORT[30], spine_mac=SPINE2_MAC, edge_mac=EDGE3_MAC)
print("  Edge 3: member 31 (P29->%d), member 32 (P30->%d)" % (DEV_PORT[29], DEV_PORT[30]))

# Edge 4 members: P31 (Spine1), P32 (Spine2)
flowlet_ecmp_selector.add_with_set_uplink(action_member_id=41, port=DEV_PORT[31], spine_mac=SPINE1_MAC, edge_mac=EDGE4_MAC)
flowlet_ecmp_selector.add_with_set_uplink(action_member_id=42, port=DEV_PORT[32], spine_mac=SPINE2_MAC, edge_mac=EDGE4_MAC)
print("  Edge 4: member 41 (P31->%d), member 42 (P32->%d)" % (DEV_PORT[31], DEV_PORT[32]))

# Step 2: 创建 selector groups (每个 Edge 一个 group，包含 2 个 members)
print("Step 2: Creating Flowlet ECMP groups...")

flowlet_ecmp_sel_grp.add(selector_group_id=1, action_member_id=[11, 12], action_member_status=[True, True], max_group_size=2)
flowlet_ecmp_sel_grp.add(selector_group_id=2, action_member_id=[21, 22], action_member_status=[True, True], max_group_size=2)
flowlet_ecmp_sel_grp.add(selector_group_id=3, action_member_id=[31, 32], action_member_status=[True, True], max_group_size=2)
flowlet_ecmp_sel_grp.add(selector_group_id=4, action_member_id=[41, 42], action_member_status=[True, True], max_group_size=2)
print("  Created 4 groups: Group 1-4")

# Step 3: 配置 flowlet_uplink 表，将每个 Edge 指向对应的 group
print("Step 3: Configuring flowlet_uplink table entries...")

flowlet_uplink_table.add(src_edge=1, selector_group_id=1)
flowlet_uplink_table.add(src_edge=2, selector_group_id=2)
flowlet_uplink_table.add(src_edge=3, selector_group_id=3)
flowlet_uplink_table.add(src_edge=4, selector_group_id=4)

print("  Edge 1 -> Group 1 (P25/Spine1, P26/Spine2)")
print("  Edge 2 -> Group 2 (P27/Spine1, P28/Spine2)")
print("  Edge 3 -> Group 3 (P29/Spine1, P30/Spine2)")
print("  Edge 4 -> Group 4 (P31/Spine1, P32/Spine2)")

# Step 4: 配置 saved_path_uplink 表 (用于同一flowlet内的路径复用)
print("Step 4: Configuring saved_path_uplink table...")

# 每个Edge配置两个可能的路径选择
saved_path_uplink_table.add_with_forward_saved_path(
    src_edge=1,
    port1=DEV_PORT[25], spine_mac1=SPINE1_MAC, edge_mac1=EDGE1_MAC,
    port2=DEV_PORT[26], spine_mac2=SPINE2_MAC, edge_mac2=EDGE1_MAC
)

saved_path_uplink_table.add_with_forward_saved_path(
    src_edge=2,
    port1=DEV_PORT[27], spine_mac1=SPINE1_MAC, edge_mac1=EDGE2_MAC,
    port2=DEV_PORT[28], spine_mac2=SPINE2_MAC, edge_mac2=EDGE2_MAC
)

saved_path_uplink_table.add_with_forward_saved_path(
    src_edge=3,
    port1=DEV_PORT[29], spine_mac1=SPINE1_MAC, edge_mac1=EDGE3_MAC,
    port2=DEV_PORT[30], spine_mac2=SPINE2_MAC, edge_mac2=EDGE3_MAC
)

saved_path_uplink_table.add_with_forward_saved_path(
    src_edge=4,
    port1=DEV_PORT[31], spine_mac1=SPINE1_MAC, edge_mac1=EDGE4_MAC,
    port2=DEV_PORT[32], spine_mac2=SPINE2_MAC, edge_mac2=EDGE4_MAC
)

print("  Configured saved path table for all 4 edges")

print("")

print("\n" + "="*60)
print("  Flowlet-based Clos Setup Complete!")
print("="*60)
print("Features enabled:")
print("  - Flowlet-aware load balancing (64μs timeout)")
print("  - Per-flow path consistency within flowlets")
print("  - Dynamic path re-selection between flowlets")
print("  - Register-based flowlet state tracking")
print("="*60)