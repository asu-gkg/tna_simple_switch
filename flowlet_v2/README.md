# Flowlet (Tofino1 / TNA 版本)

本目录已**仅保留**可在 **Tofino1 (TNA)** 后端编译的最小 Flowlet Switching 数据面实现。

## 入口文件

- `tofino/flowlet_tna.p4`

## 目录结构

- `tofino/headers.p4`：以太网/ARP/IPv4/TCP/UDP 头定义
- `tofino/metadata.p4`：元数据与常量（flowlet timeout、寄存器规模等）
- `tofino/parsers/*`：TNA ingress/egress parser
- `tofino/controls/ingress.p4`：核心逻辑（ARP reply + flowlet 寄存器更新 + IPv4 LPM + ECMP）
- `tofino/controls/egress.p4`：最小 egress（主要逻辑在 ingress）
- `tofino/deparsers/*`：deparser（egress 侧更新 IPv4 checksum）

## 用 SDE 编译（示例）

你可以直接把 `P4_PATH` 指向本项目入口：

```bash
cd $SDE/p4-build-9.1.0

./configure --prefix=$SDE_INSTALL --with-tofino \
  P4_NAME=flowlet_tna \
  P4_PATH=/home/asu/p4proj/flowlet/tofino/flowlet_tna.p4 \
  P4_VERSION=p4-16 P4_ARCHITECTURE=tna

make 

make install
```



