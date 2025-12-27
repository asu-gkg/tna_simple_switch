# 检查 Clos 表配置
p4 = bfrt.tna_simple_switch.pipe
clos = p4.SwitchIngress.clos

print("\n" + "="*60)
print("port_to_edge table - 检查入端口是否用 DEV_PORT")
print("期望: 128 (P1), 136 (P2) -> Edge 1, DOWNLINK")
print("="*60)
clos.port_to_edge.dump(from_hw=True)

print("\n" + "="*60)
print("local_forward table - 检查出端口是否用 DEV_PORT")
print("期望: 172.1.1.2 -> port 128, 172.1.1.3 -> port 136")
print("="*60)
clos.local_forward.dump(from_hw=True)

print("\n" + "="*60)
print("dst_to_edge table")
print("="*60)
clos.dst_to_edge.dump(from_hw=True)
