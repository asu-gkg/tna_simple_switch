// -------------------------
// 头部/元数据定义（metadata.p4）
// -------------------------
定义 ethernet/ipv4/arp/tcp/udp 头；
定义 ingress/egress metadata 结构、lookup_fields、Clos 相关常量。

// -------------------------
// Parser（parsers/ ）
// -------------------------
SwitchIngressParser:
  - 解析 intrinsic metadata；
  - 解析 ethernet，识别 IPv4/ARP；
  - IPv4：验证 checksum、提取 L4；
SwitchEgressParser:
  - 解析 intrinsic metadata；
  - 解析 ethernet，IPv4/ARP 逻辑同上。

// -------------------------
// 控制器组合（controls/ ）
// -------------------------
入站主控制 SwitchIngress：
  如果 ARP 请求且命中 arp_reply：回应并退出；
  调用 PktValidation 提取 5-tuple；
  先交给 ClosForwarding：
    - 根据 ingress_port 查 Edge；
    - 如果是 IPv4 及下行端口，判断是本 Edge 内（local_forward）还是跨 Edge（ecmp_uplink）；
    - 如果 Clos 处理出 egress_port，就结束；
  否则走一般流程：
    - PortMapping 设置 BD/vrf；
    - rmac 判断目标 MAC 是否本机；
      - 如果匹配，调用 FIB（仅 IPv4）决定 nexthop；
    - Nexthop 处理：
      - 先执行 nexthop 表；
      - 不命中则走 ecmp 表（ActionSelector + hash）；
      - 成功后做 TTL/SMAC 重写；
    - MAC 表查 BD + dst MAC，填入 egress_ifindex；
    - LAG 也用 5-tuple hash 选出口；
  出站控制 SwitchEgress：不做额外处理。

PktValidation：
  - 检查 Ethernet/IPv4，有效则填充 lookup_fields 与 L4 端口；

PortMapping：
  - 端口 -> ifindex；
  - ifindex -> BD/VRF；

ClosForwarding：
  - Downlink：同 Edge -> local_forward；跨 Edge -> ecmp_uplink（ActionSelector）；
  - Uplink：直接 local_forward；

MAC/FIB/Nexthop/LAG：分别做 MAC 查、FIB 查、ECMP 选择、链路聚合。

// -------------------------
// Deparser（deparsers/ ）
// -------------------------
SwitchIngressDeparser：按 ethernet/arp/ipv4/tcp/udp 发包；
SwitchEgressDeparser：重算 IPv4 checksum 后发包；

// -------------------------
// Pipeline 定义（tna_simple_switch.p4）
// -------------------------
Pipeline(
  SwitchIngressParser(),
  SwitchIngress(),
  SwitchIngressDeparser(),
  SwitchEgressParser(),
  SwitchEgress(),
  SwitchEgressDeparser()
)
Switch(pipe) main;