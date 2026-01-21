#!/usr/bin/env python
"""
BFRT control-plane script for dpc_sched.
Usage: $SDE/run_bfshell.sh -b /home/asu/p4proj/dpc_sched/bfrt_setup.py
"""

# =============================================================================
# Configuration (edit for your topology)
# =============================================================================
# P4 program name (adjust if your compiled P4 name differs)
P4_PROGRAM = "dpc_sched"

# DEV_PORT mapping (copied from clos_setup.py)
DEV_PORT = {
    1: 128, 2: 136, 3: 144, 4: 152,   # downlink
    5: 160, 6: 168, 7: 176, 8: 184,   # downlink
    25: 188, 26: 180, 27: 172, 28: 164,  # uplink
    29: 148, 30: 156, 31: 132, 32: 140,  # uplink
}

# Edge MACs (for proxy ARP)
EDGE1_MAC = 0x001111110001
EDGE2_MAC = 0x001111110002
EDGE3_MAC = 0x001111110003
EDGE4_MAC = 0x001111110004

# Spine MACs (next-hop MACs for uplinks)
SPINE1_MAC = 0x0090fb64cd44
SPINE2_MAC = 0x0090fb64cd44

# Host MAC addresses (from PHYSICAL_CONNECTIONS.md)
H1_MAC = 0xb8cef6fd0f48  # 172.1.1.2
H2_MAC = 0xb8cef6fc567e  # 172.1.1.3
H3_MAC = 0xb8cef6f8c87a  # 172.2.1.2
H4_MAC = 0xb8cef6fd1088  # 172.2.1.3
H5_MAC = 0xb49691d4fab0  # 172.3.1.2
H6_MAC = 0xb49691d4fab1  # 172.3.1.3
H7_MAC = 0xb49691af45b8  # 172.4.1.2
H8_MAC = 0xb49691af45b9  # 172.4.1.3

# Uplink to downlink forwarding: (uplink_ports, dst_ip, dst_mac, downlink_port)
# From Spine back to hosts
UPLINK_TO_DOWNLINK = [
    # Edge 1: uplinks 25,26 -> hosts h1,h2
    {"uplinks": [DEV_PORT[25], DEV_PORT[26]], "dst_ip": 0xAC010102, "dmac": H1_MAC, "port": DEV_PORT[1]},  # 172.1.1.2
    {"uplinks": [DEV_PORT[25], DEV_PORT[26]], "dst_ip": 0xAC010103, "dmac": H2_MAC, "port": DEV_PORT[2]},  # 172.1.1.3
    # Edge 2: uplinks 27,28 -> hosts h3,h4
    {"uplinks": [DEV_PORT[27], DEV_PORT[28]], "dst_ip": 0xAC020102, "dmac": H3_MAC, "port": DEV_PORT[3]},  # 172.2.1.2
    {"uplinks": [DEV_PORT[27], DEV_PORT[28]], "dst_ip": 0xAC020103, "dmac": H4_MAC, "port": DEV_PORT[4]},  # 172.2.1.3
    # Edge 3: uplinks 29,30 -> hosts h5,h6
    {"uplinks": [DEV_PORT[29], DEV_PORT[30]], "dst_ip": 0xAC030102, "dmac": H5_MAC, "port": DEV_PORT[5]},  # 172.3.1.2
    {"uplinks": [DEV_PORT[29], DEV_PORT[30]], "dst_ip": 0xAC030103, "dmac": H6_MAC, "port": DEV_PORT[6]},  # 172.3.1.3
    # Edge 4: uplinks 31,32 -> hosts h7,h8
    {"uplinks": [DEV_PORT[31], DEV_PORT[32]], "dst_ip": 0xAC040102, "dmac": H7_MAC, "port": DEV_PORT[7]},  # 172.4.1.2
    {"uplinks": [DEV_PORT[31], DEV_PORT[32]], "dst_ip": 0xAC040103, "dmac": H8_MAC, "port": DEV_PORT[8]},  # 172.4.1.3
]

# Downlink ports and their two uplinks (per-edge)
# Each downlink gets two entries: ecmp_idx=0/1.
DOWNLINK_ECMP = {
    DEV_PORT[1]: (DEV_PORT[25], DEV_PORT[26]),
    DEV_PORT[2]: (DEV_PORT[25], DEV_PORT[26]),
    DEV_PORT[3]: (DEV_PORT[27], DEV_PORT[28]),
    DEV_PORT[4]: (DEV_PORT[27], DEV_PORT[28]),
    DEV_PORT[5]: (DEV_PORT[29], DEV_PORT[30]),
    DEV_PORT[6]: (DEV_PORT[29], DEV_PORT[30]),
    DEV_PORT[7]: (DEV_PORT[31], DEV_PORT[32]),
    DEV_PORT[8]: (DEV_PORT[31], DEV_PORT[32]),
}

# Proxy ARP entries: target protocol address -> reply MAC
ARP_ENTRIES = [
    # Edge 1: 172.1.1.1/2/3
    {"tpa": 0xAC010101, "mac": EDGE1_MAC},
    {"tpa": 0xAC010102, "mac": EDGE1_MAC},
    {"tpa": 0xAC010103, "mac": EDGE1_MAC},
    # Edge 2: 172.2.1.1/2/3
    {"tpa": 0xAC020101, "mac": EDGE2_MAC},
    {"tpa": 0xAC020102, "mac": EDGE2_MAC},
    {"tpa": 0xAC020103, "mac": EDGE2_MAC},
    # Edge 3: 172.3.1.1/2/3
    {"tpa": 0xAC030101, "mac": EDGE3_MAC},
    {"tpa": 0xAC030102, "mac": EDGE3_MAC},
    {"tpa": 0xAC030103, "mac": EDGE3_MAC},
    # Edge 4: 172.4.1.1/2/3
    {"tpa": 0xAC040101, "mac": EDGE4_MAC},
    {"tpa": 0xAC040102, "mac": EDGE4_MAC},
    {"tpa": 0xAC040103, "mac": EDGE4_MAC},
    # Underlay proxy ARP (172.16.x.0 and 172.16.x.2)
    {"tpa": 0xAC100100, "mac": EDGE1_MAC},
    {"tpa": 0xAC100102, "mac": EDGE1_MAC},
    {"tpa": 0xAC100200, "mac": EDGE2_MAC},
    {"tpa": 0xAC100202, "mac": EDGE2_MAC},
    {"tpa": 0xAC100300, "mac": EDGE3_MAC},
    {"tpa": 0xAC100302, "mac": EDGE3_MAC},
    {"tpa": 0xAC100400, "mac": EDGE4_MAC},
    {"tpa": 0xAC100402, "mac": EDGE4_MAC},
]

# MSB extraction parameters
TS_WIDTH = 32
EXP_RANGE = 32  # program exp in [0, 31]


# =============================================================================
# BFRT table handles
# =============================================================================
try:
    p4 = getattr(bfrt, P4_PROGRAM).pipe
except Exception:
    raise RuntimeError("P4 program '%s' not found in BFRT" % P4_PROGRAM)


def get_ingress_control(p4_pipe, program_name):
    if not hasattr(p4_pipe, "SwitchIngress"):
        raise RuntimeError("SwitchIngress not found in BFRT program '%s'" % program_name)
    si = p4_pipe.SwitchIngress
    if hasattr(si, "dpc_sched"):
        return si.dpc_sched
    return si


def get_table(node, name):
    if hasattr(node, name):
        return getattr(node, name)
    children = [n for n in dir(node) if not n.startswith("_")]
    candidates = [n for n in children if n.endswith(name)]
    if len(candidates) == 1:
        return getattr(node, candidates[0])
    print("Available tables/controls under %s:" % node)
    print(", ".join(sorted(children)))
    raise RuntimeError("Table '%s' not found in BFRT" % name)


ingress = get_ingress_control(p4, P4_PROGRAM)

# ARP table lives under arp_control in this pipeline
arp_table = get_table(ingress.arp_control, "arp_reply_table")

uplink_table = get_table(ingress, "uplink_port_ip_to_nhop")
downlink_table = get_table(ingress, "downlink_to_uplink_port")
msb_comm_table = get_table(ingress, "msb_comm_table")
msb_comp_table = get_table(ingress, "msb_comp_table")
cmp_exp_table = get_table(ingress, "cmp_exp_table")

# =============================================================================
# Helpers
# =============================================================================
def clear_table(table, name):
    try:
        table.clear()
        print("Cleared %s" % name)
    except Exception as e:
        print("Skip clear %s: %s" % (name, str(e)))


def program_arp(arp_tbl, entries):
    print("\nProgramming ARP replies...")
    for entry in entries:
        arp_tbl.add_with_do_arp_reply(tpa=entry["tpa"], my_mac=entry["mac"])


def program_uplink_to_downlink(uplink_tbl, entries):
    print("\nProgramming uplink_port_ip_to_nhop...")
    for entry in entries:
        for uplink_port in entry["uplinks"]:
            uplink_tbl.add_with_set_nhop(
                ingress_port=uplink_port,
                dst_addr=entry["dst_ip"],
                dmac=entry["dmac"],
                port=entry["port"],
            )


def program_downlink_to_uplink(downlink_tbl, downlink_ecmp, spine1_mac, spine2_mac):
    print("\nProgramming downlink_to_uplink_port...")
    for dl_port, uplinks in downlink_ecmp.items():
        uplink0, uplink1 = uplinks
        downlink_tbl.add_with_set_nhop(
            ingress_port=dl_port,
            ecmp_idx=0,
            dmac=spine1_mac,
            port=uplink0,
        )
        downlink_tbl.add_with_set_nhop(
            ingress_port=dl_port,
            ecmp_idx=1,
            dmac=spine2_mac,
            port=uplink1,
        )


def program_msb_table(table, key_name, action_name, exp_range, ts_width):
    add_fn = getattr(table, "add_with_%s" % action_name)
    mask_name = key_name + "_mask"
    for e in range(exp_range):
        value = 1 << e
        mask = ((1 << ts_width) - 1) & (~((1 << e) - 1))  # 0xFFFFFFFF << e
        kwargs = {key_name: value, mask_name: mask, "e": e}
        add_fn(**kwargs)


def program_cmp_exp(cmp_tbl, exp_range):
    print("\nProgramming cmp_exp_table (inc_qos = 1 if exp_comm > exp_comp)...")
    for exp_comm in range(exp_range):
        for exp_comp in range(exp_range):
            inc = 1 if exp_comm > exp_comp else 0
            cmp_tbl.add_with_set_inc(
                exp_comm=exp_comm, exp_comp=exp_comp, v=inc
            )


# =============================================================================
# Main
# =============================================================================
print("\n" + "=" * 60)
print("  BFRT setup for dpc_sched")
print("=" * 60 + "\n")

print("Clearing tables...")
clear_table(arp_table, "arp_reply_table")
clear_table(uplink_table, "uplink_port_ip_to_nhop")
clear_table(downlink_table, "downlink_to_uplink_port")
clear_table(msb_comm_table, "msb_comm_table")
clear_table(msb_comp_table, "msb_comp_table")
clear_table(cmp_exp_table, "cmp_exp_table")
print("Tables cleared.\n")

program_arp(arp_table, ARP_ENTRIES)
program_uplink_to_downlink(uplink_table, UPLINK_TO_DOWNLINK)
program_downlink_to_uplink(downlink_table, DOWNLINK_ECMP, SPINE1_MAC, SPINE2_MAC)
print("\nProgramming msb_comm_table...")
program_msb_table(msb_comm_table, "ts_communication", "set_exp_comm", EXP_RANGE, TS_WIDTH)
print("Programming msb_comp_table...")
program_msb_table(msb_comp_table, "ts_computation", "set_exp_comp", EXP_RANGE, TS_WIDTH)
program_cmp_exp(cmp_exp_table, EXP_RANGE)

print("\nSetup complete.")
