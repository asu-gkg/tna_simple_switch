# tna_simple_switch

## 概述

* **名称**: tna_simple_switch
* **P4 版本**: P4_16
* **架构**: Tofino Native Architecture (TNA)
* **编程接口**: Barefoot Runtime Interface (BRI)

一个功能丰富的 L2/L3 交换机实现，支持以下功能：

- L2 交换（支持 VLAN）
- IPv4/IPv6 路由
- ARP 响应
- Segment Routing (SRv6)
- ECMP 和链路聚合
- **Clos 拓扑 ECMP 转发**（新增）

---

## Clos 拓扑 ECMP 功能

### 拓扑结构

本程序支持使用单台物理交换机模拟 4 个逻辑 Edge（Leaf）的 Clos 拓扑：

```
                     物理 Spine Switch（普通 L3）
                     ┌──────────────────────────────┐
                     │           Spine              │
                     └──┬───┬───┬───┬───┬───┬───┬──┘
                        │   │   │   │   │   │   │
        Spine1 links:  P25 P27 P29 P31
        Spine2 links:      P26 P28 P30 P32
                        │   │   │   │   │   │   │
┌───────────────────────┴───┴───┴───┴───┴───┴───┴───┐
│              物理 Edge Switch (P4 可编程)          │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  │
│  │ Edge 1 │  │ Edge 2 │  │ Edge 3 │  │ Edge 4 │  │
│  │ P1,P2  │  │ P3,P4  │  │ P5,P6  │  │ P7,P8  │  │
│  └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘  │
└──────┼───────────┼───────────┼───────────┼───────┘
      P1,P2       P3,P4       P5,P6       P7,P8
       │           │           │           │
     h1,h2       h3,h4       h5,h6       h7,h8
```

### 物理端口映射

| 逻辑 Edge | 下行端口 (→主机) | 上行到 Spine1 | 上行到 Spine2 |
|----------|-----------------|--------------|--------------|
| Edge 1   | P1, P2          | P25          | P26          |
| Edge 2   | P3, P4          | P27          | P28          |
| Edge 3   | P5, P6          | P29          | P30          |
| Edge 4   | P7, P8          | P31          | P32          |

### IP 地址规划

**主机子网（/29）：**
- Edge 1: `172.1.1.0/29` (GW: 172.1.1.1, h1: .2, h2: .3)
- Edge 2: `172.2.1.0/29` (GW: 172.2.1.1, h3: .2, h4: .3)
- Edge 3: `172.3.1.0/29` (GW: 172.3.1.1, h5: .2, h6: .3)
- Edge 4: `172.4.1.0/29` (GW: 172.4.1.1, h7: .2, h8: .3)

**Underlay 互联（/31 P2P）：**
- Edge 1 ↔ Spine 1: `172.16.1.0/31`
- Edge 1 ↔ Spine 2: `172.16.1.2/31`
- Edge 2 ↔ Spine 1: `172.16.2.0/31`
- Edge 2 ↔ Spine 2: `172.16.2.2/31`
- Edge 3 ↔ Spine 1: `172.16.3.0/31`
- Edge 3 ↔ Spine 2: `172.16.3.2/31`
- Edge 4 ↔ Spine 1: `172.16.4.0/31`
- Edge 4 ↔ Spine 2: `172.16.4.2/31`

### 转发逻辑

| 流量类型 | 示例 | 处理方式 |
|---------|------|---------|
| 同 Edge 内 | h1 → h2 | 直接转发，不经过 Spine |
| 跨 Edge | h1 → h5 | ECMP 选择 Spine1 或 Spine2 |
| 从 Spine 下来 | P25 入 → h1 | 查本地转发表，发到目的主机 |

**ECMP Hash 字段（5-tuple）：**
- 源 IP 地址
- 目的 IP 地址
- IP 协议号
- 源端口（TCP/UDP）
- 目的端口（TCP/UDP）

### 配置 Clos 转发

```bash
# 运行配置脚本
$SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/clos_setup.py
```

配置脚本会设置：
1. **port_to_edge 表**：端口 → 逻辑 Edge 映射
2. **dst_to_edge 表**：目的 IP 子网 → 逻辑 Edge 映射
3. **local_forward 表**：目的 IP → 出端口 + MAC
4. **ecmp_uplink 表**：ECMP 上行端口选择
5. **arp_reply_table**：ARP 响应配置

---

## 环境准备

### 1. 设置环境变量

```bash
# 设置 SDE 路径
export SDE=/home/asu/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
export LD_LIBRARY_PATH=$SDE_INSTALL/lib:$LD_LIBRARY_PATH
```

建议将以上内容添加到 `~/.bashrc` 中：

```bash
echo 'export SDE=/home/asu/bf-sde-9.1.0' >> ~/.bashrc
echo 'export SDE_INSTALL=$SDE/install' >> ~/.bashrc
echo 'export PATH=$SDE_INSTALL/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=$SDE_INSTALL/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

---

## 编译 P4 程序

### 方法一：使用 p4-build（推荐）

```bash
# 进入 p4-build 目录
cd $SDE/p4-build-9.1.0

# 清理之前的编译（如果有）
make clean 2>/dev/null || true

# 配置编译参数
./configure --prefix=$SDE_INSTALL \
    --with-tofino \
    P4_NAME=tna_simple_switch \
    P4_PATH=/home/asu/p4proj/tna_simple_switch/tna_simple_switch.p4 \
    P4_VERSION=p4-16 \
    P4_ARCHITECTURE=tna

# 编译
make

# 安装编译产物
make install
```

### 方法二：直接使用 bf-p4c 编译器

```bash
# 创建输出目录
mkdir -p $SDE_INSTALL/share/tofinopd/tna_simple_switch/pipe

# 编译 P4 程序
bf-p4c --std p4-16 \
    --arch tna \
    --target tofino \
    -o $SDE_INSTALL/share/tofinopd/tna_simple_switch/pipe \
    /home/asu/p4proj/tna_simple_switch/tna_simple_switch.p4

# 生成 bf-rt.json（如果需要）
p4c-gen-bfrt-conf \
    --bf-rt-schema $SDE_INSTALL/share/tofinopd/tna_simple_switch/bf-rt.json \
    /home/asu/p4proj/tna_simple_switch/tna_simple_switch.p4
```

### 验证编译结果

```bash
# 检查编译产物是否存在
ls -la $SDE_INSTALL/share/tofinopd/tna_simple_switch/
ls -la $SDE_INSTALL/share/tofinopd/tna_simple_switch/pipe/

# 应该看到以下文件：
# - bf-rt.json
# - pipe/context.json
# - pipe/tofino.bin
```

---

## 创建 BSPless 配置文件

BSPless 模式用于直接访问 Tofino 硬件，无需完整的 Board Support Package。

### 配置说明

| 配置项 | 说明 |
|--------|------|
| `pcie_bus: 6` | PCIe 总线地址，根据实际硬件调整 |
| `pipe_scope: [0, 1, 2, 3]` | 使用所有 4 个流水线（Tofino 硬件最大支持 4 个） |
| `board-port-map` | 端口映射文件，Wedge100BF-32X 使用 `accton_wedge_32x_port_map.json` |

---

## 运行 P4 程序（Tofino 硬件）

### 步骤 1：启动 bf_switchd

```bash
# 方法一：使用程序名（自动查找配置文件）
sudo $SDE/run_switchd.sh -p tna_simple_switch

# 方法二：使用 BSPless 配置文件（推荐）
sudo $SDE/run_switchd.sh -c $SDE_INSTALL/share/p4/targets/tofino/tna_simple_switch-bspless.conf

# 方法三：直接运行 bf_switchd
sudo env "PATH=$PATH" "LD_LIBRARY_PATH=$LD_LIBRARY_PATH" bf_switchd \
    --install-dir $SDE_INSTALL \
    --conf-file $SDE_INSTALL/share/p4/targets/tofino/tna_simple_switch-bspless.conf
```

### 步骤 2：Bring Up 端口

P4-16 程序不会自动初始化端口，需要手动 bring up。

#### 方法一：使用 bringUpPorts.cmd 脚本

```bash
# 在另一个终端执行
$SDE_INSTALL/bin/bfshell -f /home/asu/p4proj/tna_simple_switch/bringUpPorts.cmd
```

#### 方法二：在 bfshell 中手动操作

在 `bfshell>` 提示符下依次输入：

```
ucli
pm
port-add 1/0 40G NONE
port-add 2/0 40G NONE
an-set 1/0 2
an-set 2/0 2
port-enb 1/0
port-enb 2/0
show
```

#### 方法三：查看端口状态

```
bfshell> ucli
bf-sde> pm
bf-sde.pm> show
bf-sde.pm> show -p 1/0
bf-sde.pm> show -p 2/0
```

等待 3-5 秒后，确认端口 `OPR=UP`。

### 步骤 3：连接 bfshell（可选）

启动成功后，可以在另一个终端使用 bfshell 进行交互：

```bash
$SDE/run_bfshell.sh
```

或者使用 bfrt_python：

```bash
$SDE/run_bfshell.sh -b /path/to/your/setup_script.py
```

---

## 配置 ARP 表

### 方法一：使用配置脚本（推荐）

1. 先编辑脚本，配置交换机的 IP 和 MAC：

```bash
vim /home/asu/p4proj/tna_simple_switch/arp_setup.py
```

修改 `SWITCH_INTERFACES` 配置：

```python
SWITCH_INTERFACES = [
    # (IP 地址十六进制, MAC 地址十六进制)
    (0x0A000001, 0x001111111111),   # 10.0.0.1 -> 00:11:11:11:11:11
]
```

2. 执行脚本：

```bash
$SDE/run_bfshell.sh -b /home/asu/p4proj/tna_simple_switch/arp_setup.py
```

### 方法二：在 bfrt_python 中手动配置

```bash
$SDE/run_bfshell.sh
```

然后在 `bfshell>` 中输入：

```
bfrt_python
```

在 Python 环境中执行：

```python
# 获取 ARP 表
p4 = bfrt.tna_simple_switch.pipe
arp_table = p4.SwitchIngress.arp_reply_table

# 添加 ARP 表项：当查询 10.0.0.1 时，返回 MAC 00:11:11:11:11:11
arp_table.add_with_do_arp_reply(
    tpa=0x0A000001,       # 10.0.0.1
    my_mac=0x001111111111  # 00:11:11:11:11:11
)

# 查看表项
arp_table.dump(table=True)
```

---

## 测试 ARP 功能

### 步骤 1：在主机上发送 ARP 请求

假设主机连接在交换机端口 1/0，配置了交换机 IP 为 10.0.0.1：

```bash
# 在主机上执行（需要 root 权限）
# 将 enp6s27f0np0 替换为实际网卡名
sudo arping -I enp6s27f0np0 172.1.1.1 -c 3
```

### 步骤 2：使用 tcpdump 抓包验证

在主机上同时运行：

```bash
sudo tcpdump -i enp6s27f0np0 arp -nn -e
```

### 步骤 3：使用 scapy 发送 ARP 请求（更灵活）

```python
# 在主机上执行
python3 - <<'PY'
from scapy.all import Ether, ARP, sendp, sniff
import threading

iface = "enp6s27f0np0"  # 替换为实际网卡名
src_mac = "b8:ce:f6:fc:56:7e"  # 主机的 MAC
src_ip = "10.0.0.100"  # 主机的 IP
dst_ip = "10.0.0.1"  # 交换机的 IP（ARP 表中配置的）

# 构造 ARP 请求包
arp_request = Ether(dst="ff:ff:ff:ff:ff:ff", src=src_mac) / \
              ARP(op=1, hwsrc=src_mac, psrc=src_ip, hwdst="00:00:00:00:00:00", pdst=dst_ip)

print("Sending ARP request for %s..." % dst_ip)
arp_request.show()

# 发送并等待响应
sendp(arp_request, iface=iface, verbose=False)
print("\nARP request sent! Check tcpdump for response.")
PY
```

### 预期结果

如果 P4 程序正常工作：

1. 交换机收到 ARP 请求（查询 10.0.0.1）
2. 匹配 `arp_reply_table` 表项
3. 执行 `do_arp_reply` 动作，构造 ARP 响应
4. 从原端口返回 ARP 响应
5. 主机收到 ARP 响应，显示 10.0.0.1 的 MAC 是 00:11:11:11:11:11

tcpdump 输出示例：

```
ARP, Request who-has 10.0.0.1 tell 10.0.0.100, length 28
ARP, Reply 10.0.0.1 is-at 00:11:11:11:11:11, length 28
```

---

## 运行 PTF 测试

```bash
# 运行所有测试
sudo $SDE/run_p4_tests.sh \
    -p tna_simple_switch \
    -t /home/asu/p4proj/tna_simple_switch

# 运行特定测试
sudo $SDE/run_p4_tests.sh \
    -p tna_simple_switch \
    -t /home/asu/p4proj/tna_simple_switch \
    -s tests.YourTestClassName
```

---

## 故障排除

### 问题：找不到配置文件

```bash
# 检查配置文件是否存在
ls -la $SDE_INSTALL/share/p4/targets/tofino/tna_simple_switch*.conf

# 如果不存在，重新编译或创建 bspless 配置文件
```

### 问题：编译失败

```bash
# 检查编译器是否可用
which bf-p4c

# 检查依赖是否安装
$SDE_INSTALL/bin/bf-p4c --version
```

### 问题：switchd 启动失败

```bash
# 检查是否有足够的 hugepages
cat /proc/meminfo | grep Huge

# 设置 hugepages（如果需要）
sudo sysctl -w vm.nr_hugepages=128
```

### 问题：权限不足

```bash
# switchd 需要 root 权限
sudo $SDE/run_switchd.sh -p tna_simple_switch
```

---

## 文件结构

```
/home/asu/p4proj/tna_simple_switch/
├── tna_simple_switch.p4    # 主 P4 程序
├── headers.p4              # 头部定义
├── parde.p4                # Parser/Deparser
├── srv6.p4                 # SRv6 处理逻辑
├── tests.py                # PTF 测试
└── README.md               # 本文档

编译产物位置：
$SDE_INSTALL/share/tofinopd/tna_simple_switch/
├── bf-rt.json              # BF-RT 配置
└── pipe/
    ├── context.json        # Pipeline 上下文
    └── tofino.bin          # 编译后的二进制
```

