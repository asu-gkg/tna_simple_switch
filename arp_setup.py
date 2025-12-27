#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
配置 tna_simple_switch 的 ARP 表

使用方法:
    $SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/arp_setup.py
"""

# 获取 bfrt 对象
p4 = bfrt.tna_simple_switch.pipe
arp_table = p4.SwitchIngress.arp_reply_table

#==============================================================================
# 配置参数 - 交换机响应的 IP 和 MAC
# MAC 地址: 00:11:11:11:11:11 = 0x001111111111
#==============================================================================

SWITCH_MAC = 0x001111111111

# IP 地址列表 (十六进制)
IP_LIST = [
    0xAC010101,   # 172.1.1.1
    0xAC020101,   # 172.2.1.1
    0xAC030101,   # 172.3.1.1
    0xAC040101,   # 172.4.1.1
    0xAC100100,   # 172.16.1.0
    0xAC100200,   # 172.16.2.0
    0xAC100300,   # 172.16.3.0
    0xAC100400,   # 172.16.4.0
]

#==============================================================================
# 执行配置
#==============================================================================

print("\n" + "="*60)
print("Setting up ARP table for tna_simple_switch")
print("="*60 + "\n")

for ip in IP_LIST:
    ip_str = '%d.%d.%d.%d' % ((ip >> 24) & 0xFF, (ip >> 16) & 0xFF, (ip >> 8) & 0xFF, ip & 0xFF)
    print("Adding: %s -> 00:11:11:11:11:11" % ip_str)
    try:
        arp_table.add_with_do_arp_reply(tpa=ip, my_mac=SWITCH_MAC)
        print("  OK")
    except Exception as e:
        print("  Error: %s" % str(e))

print("\n=== ARP Table Entries ===")
arp_table.dump(table=True)
print("\nARP setup complete!")
