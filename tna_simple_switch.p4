/*******************************************************************************
 * BAREFOOT NETWORKS CONFIDENTIAL & PROPRIETARY
 *
 * Copyright (c) 2019-present Barefoot Networks, Inc.
 *
 * All Rights Reserved.
 *
 * NOTICE: All information contained herein is, and remains the property of
 * Barefoot Networks, Inc. and its suppliers, if any. The intellectual and
 * technical concepts contained herein are proprietary to Barefoot Networks, Inc.
 * and its suppliers and may be covered by U.S. and Foreign Patents, patents in
 * process, and are protected by trade secret or copyright law.  Dissemination of
 * this information or reproduction of this material is strictly forbidden unless
 * prior written permission is obtained from Barefoot Networks, Inc.
 *
 * No warranty, explicit or implicit is provided, unless granted under a written
 * agreement with Barefoot Networks, Inc.
 *
 ******************************************************************************/

#include <core.p4>
#include <tna.p4>
#include "headers.p4"

// Common types
typedef bit<16> bd_t;
typedef bit<16> vrf_t;
typedef bit<16> nexthop_t;
typedef bit<16> ifindex_t;

typedef bit<8> bypass_t;
const bypass_t BYPASS_L2 = 8w0x01;
const bypass_t BYPASS_L3 = 8w0x02;
const bypass_t BYPASS_ACL = 8w0x04;
// Add more bypass flags here.
const bypass_t BYPASS_ALL = 8w0xff;
#define BYPASS(t) (ig_md.bypass & BYPASS_##t != 0)

// =============================================================================
// Clos Topology Types and Constants
// =============================================================================
typedef bit<8> edge_id_t;
const edge_id_t EDGE_INVALID = 0;
const edge_id_t EDGE_1 = 1;
const edge_id_t EDGE_2 = 2;
const edge_id_t EDGE_3 = 3;
const edge_id_t EDGE_4 = 4;

typedef bit<2> port_type_t;
const port_type_t PORT_TYPE_UNKNOWN = 0;
const port_type_t PORT_TYPE_DOWNLINK = 1;  // 下行端口（连主机）
const port_type_t PORT_TYPE_UPLINK = 2;    // 上行端口（连Spine）

struct ingress_metadata_t {
    bool checksum_err;
    bd_t bd;
    vrf_t vrf;
    nexthop_t nexthop;
    ifindex_t ifindex;
    ifindex_t egress_ifindex;
    bypass_t bypass;
    // Clos topology fields
    edge_id_t src_edge;       // 入端口所属的逻辑 Edge
    edge_id_t dst_edge;       // 目的 IP 所属的逻辑 Edge
    port_type_t port_type;    // 入端口类型（上行/下行）
}

struct egress_metadata_t {
    // Empty for now
}

struct lookup_fields_t {
    mac_addr_t mac_src_addr;
    mac_addr_t mac_dst_addr;
    bit<16> mac_type;

    bit<4> ip_version;
    bit<8> ip_proto;
    bit<8> ip_ttl;
    bit<8> ip_dscp;

    ipv4_addr_t ipv4_src_addr;
    ipv4_addr_t ipv4_dst_addr;
    // L4 ports for 5-tuple ECMP hash
    bit<16> l4_src_port;
    bit<16> l4_dst_port;
}

struct header_t {
    ethernet_h ethernet;
    ipv4_h ipv4;
    arp_h arp;
    tcp_h tcp;
    udp_h udp;

    // Add more headers here.
}


#include "parde.p4"


//-----------------------------------------------------------------------------
// Packet validaion
// Validate ethernet, Ipv4 or Ipv6 headers and set the common lookup fields.
//-----------------------------------------------------------------------------
control PktValidation(
        in header_t hdr, out lookup_fields_t lkp) {

    const bit<32> table_size = 512;

    action malformed_pkt() {
        // drop.
    }

    action valid_pkt_untagged() {
        lkp.mac_src_addr = hdr.ethernet.src_addr;
        lkp.mac_dst_addr = hdr.ethernet.dst_addr;
        lkp.mac_type = hdr.ethernet.ether_type;
    }

    table validate_ethernet {
        key = {
            hdr.ethernet.src_addr : ternary;
            hdr.ethernet.dst_addr : ternary;
        }

        actions = {
            malformed_pkt;
            valid_pkt_untagged;
        }

        size = table_size;
    }

//-----------------------------------------------------------------------------
// Validate outer IPv4 header and set the lookup fields.
// - Drop the packet if ttl is zero, ihl is invalid, or version is invalid.
//-----------------------------------------------------------------------------
    action valid_ipv4_pkt() {
        // Set common lookup fields
        lkp.ip_version = 4w4;
        lkp.ip_dscp = hdr.ipv4.diffserv;
        lkp.ip_proto = hdr.ipv4.protocol;
        lkp.ip_ttl = hdr.ipv4.ttl;
        lkp.ipv4_src_addr = hdr.ipv4.src_addr;
        lkp.ipv4_dst_addr = hdr.ipv4.dst_addr;
    }

    table validate_ipv4 {
        key = {
            //ig_md.checksum_err : ternary;
            hdr.ipv4.version : ternary;
            hdr.ipv4.ihl : ternary;
            hdr.ipv4.ttl : ternary;
        }

        actions = {
            valid_ipv4_pkt;
            malformed_pkt;
        }

        size = table_size;
    }

    apply {
        validate_ethernet.apply();
        if (hdr.ipv4.isValid()) {
            validate_ipv4.apply();
        }
        // Extract L4 ports for 5-tuple ECMP hash
        if (hdr.tcp.isValid()) {
            lkp.l4_src_port = hdr.tcp.src_port;
            lkp.l4_dst_port = hdr.tcp.dst_port;
        } else if (hdr.udp.isValid()) {
            lkp.l4_src_port = hdr.udp.src_port;
            lkp.l4_dst_port = hdr.udp.dst_port;
        } else {
            lkp.l4_src_port = 0;
            lkp.l4_dst_port = 0;
        }
    }
}

control PortMapping(
        in PortId_t port,
        inout ingress_metadata_t ig_md)(
        bit<32> port_table_size,
        bit<32> bd_table_size) {

    ActionProfile(bd_table_size) bd_action_profile;

    action set_port_attributes(ifindex_t ifindex) {
        ig_md.ifindex = ifindex;

        // Add more port attributes here.
    }

    table port_mapping {
        key = { port : exact; }
        actions = { set_port_attributes; }
    }

    action set_bd_attributes(bd_t bd, vrf_t vrf) {
        ig_md.bd = bd;
        ig_md.vrf = vrf;
    }

    table port_to_bd_mapping {
        key = {
            ig_md.ifindex : exact;
        }

        actions = {
            NoAction;
            set_bd_attributes;
        }

        const default_action = NoAction;
        implementation = bd_action_profile;
        size = port_table_size;
    }

    apply {
        port_mapping.apply();
        port_to_bd_mapping.apply();
    }
}

//-----------------------------------------------------------------------------
// Destination MAC lookup
// - Bridge out the packet of the interface in the MAC entry.
// - Flood the packet out of all ports within the ingress BD.
//-----------------------------------------------------------------------------
control MAC(
    in mac_addr_t dst_addr,
    in bd_t bd,
    out ifindex_t egress_ifindex)(
    bit<32> mac_table_size) {

    action dmac_miss() {
        egress_ifindex = 16w0xffff;
    }

    action dmac_hit(ifindex_t ifindex) {
        egress_ifindex = ifindex;
    }

    table dmac {
        key = {
            bd : exact;
            dst_addr : exact;
        }

        actions = {
            dmac_miss;
            dmac_hit;
        }

        const default_action = dmac_miss;
        size = mac_table_size;
    }

    apply {
        dmac.apply();
    }
}

control FIB(in ipv4_addr_t dst_addr,
            in vrf_t vrf,
            out nexthop_t nexthop)(
            bit<32> host_table_size,
            bit<32> lpm_table_size) {

    action fib_hit(nexthop_t nexthop_index) {
        nexthop = nexthop_index;
    }

    action fib_miss() { }

    table fib {
        key = {
            vrf : exact;
            dst_addr : exact;
        }

        actions = {
            fib_miss;
            fib_hit;
        }

        const default_action = fib_miss;
        size = host_table_size;
    }

    table fib_lpm {
        key = {
            vrf : exact;
            dst_addr : lpm;
        }

        actions = {
            fib_miss;
            fib_hit;
        }

        const default_action = fib_miss;
        size = lpm_table_size;
    }

    apply {
        if (!fib.apply().hit) {
            fib_lpm.apply();
        }
    }
}

// ----------------------------------------------------------------------------
// Nexthop/ECMP resolution
// ----------------------------------------------------------------------------
control Nexthop(in lookup_fields_t lkp,
                inout header_t hdr,
                inout ingress_metadata_t ig_md)(
                bit<32> table_size) {
    bool routed;
    Hash<bit<32>>(HashAlgorithm_t.CRC32) sel_hash;
    ActionSelector(
        1024, sel_hash, SelectorMode_t.FAIR) ecmp_selector;

    action set_nexthop_attributes(bd_t bd, mac_addr_t dmac) {
        routed = true;
        ig_md.bd = bd;
        hdr.ethernet.dst_addr = dmac;
    }

    table ecmp {
        key = {
            ig_md.nexthop : exact;
            lkp.ipv4_src_addr : selector;
            lkp.ipv4_dst_addr : selector;
            lkp.ip_proto : selector;
            lkp.l4_src_port : selector;
            lkp.l4_dst_port : selector;
        }

        actions = {
            NoAction;
            set_nexthop_attributes;
        }

        const default_action = NoAction;
        size = table_size;
        implementation = ecmp_selector;
    }

    table nexthop {
        key = {
            ig_md.nexthop : exact;
        }

        actions = {
            NoAction;
            set_nexthop_attributes;
        }

        const default_action = NoAction;
        size = table_size;
    }

    action rewrite_ipv4() {
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ip_rewrite {
        key = {
            hdr.ipv4.isValid() : exact;
        }

        actions = {
            rewrite_ipv4;
        }

        const entries = {
            true : rewrite_ipv4();
        }
    }


    action rewrite_smac(mac_addr_t smac) {
        hdr.ethernet.src_addr = smac;
    }

    table smac_rewrite {
        key = { ig_md.bd : exact; }
        actions = {
            NoAction;
            rewrite_smac;
        }

        const default_action = NoAction;
    }

    apply {
        routed = false;
        switch(nexthop.apply().action_run) {
            NoAction : { ecmp.apply(); }
        }

        // Decrement TTL and rewrite ethernet src addr if the packet is routed.
        if (routed) {
            ip_rewrite.apply();
            smac_rewrite.apply();
        }
    }
}

// ----------------------------------------------------------------------------
// Link Aggregation
// ----------------------------------------------------------------------------
control LAG(in lookup_fields_t lkp,
            in ifindex_t ifindex,
            out PortId_t egress_port) {
    Hash<bit<32>>(HashAlgorithm_t.CRC32) sel_hash;
    ActionSelector(1024, sel_hash, SelectorMode_t.FAIR) lag_selector;

    action set_port(PortId_t port) {
        egress_port = port;
    }

    action lag_miss() { }

    table lag {
        key = {
            ifindex : exact;
            lkp.ipv4_src_addr : selector;
            lkp.ipv4_dst_addr : selector;
            lkp.ip_proto : selector;
            lkp.l4_src_port : selector;
            lkp.l4_dst_port : selector;
        }

        actions = {
            lag_miss;
            set_port;
        }

        const default_action = lag_miss;
        size = 1024;
        implementation = lag_selector;
    }

    apply {
        lag.apply();
    }
}

// =============================================================================
// Clos Topology Forwarding
// 实现 4 个逻辑 Edge 的 ECMP 转发：
// - 下行端口 1-8 连接主机
// - 上行端口 25-32 连接 Spine
// - 每个 Edge 2 个下行端口 + 2 个上行端口（到 Spine1 和 Spine2）
// =============================================================================
control ClosForwarding(
        in lookup_fields_t lkp,
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in PortId_t ingress_port,
        inout PortId_t egress_port,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

    // -------------------------------------------------------------------------
    // Table 1: 入端口 → 逻辑 Edge + 端口类型
    // -------------------------------------------------------------------------
    action set_port_info(edge_id_t edge_id, port_type_t ptype) {
        ig_md.src_edge = edge_id;
        ig_md.port_type = ptype;
    }

    action port_info_miss() {
        ig_md.src_edge = EDGE_INVALID;
        ig_md.port_type = PORT_TYPE_UNKNOWN;
    }

    table port_to_edge {
        key = {
            ingress_port : exact;
        }
        actions = {
            set_port_info;
            port_info_miss;
        }
        const default_action = port_info_miss;
        size = 64;
    }

    // -------------------------------------------------------------------------
    // Table 2: 目的 IP → 逻辑 Edge (LPM)
    // -------------------------------------------------------------------------
    action set_dst_edge(edge_id_t edge_id) {
        ig_md.dst_edge = edge_id;
    }

    action dst_edge_miss() {
        ig_md.dst_edge = EDGE_INVALID;
    }

    table dst_to_edge {
        key = {
            hdr.ipv4.dst_addr : lpm;
        }
        actions = {
            set_dst_edge;
            dst_edge_miss;
        }
        const default_action = dst_edge_miss;
        size = 64;
    }

    // -------------------------------------------------------------------------
    // Table 3: 本地转发表（目的 IP → 出端口 + 下一跳 MAC）
    // 用于：同 Edge 内转发 或 从 Spine 下来后转发到主机
    // -------------------------------------------------------------------------
    action forward_local(PortId_t port, mac_addr_t dst_mac, mac_addr_t src_mac) {
        egress_port = port;
        hdr.ethernet.dst_addr = dst_mac;
        hdr.ethernet.src_addr = src_mac;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action local_forward_miss() {
        // Drop the packet
        ig_dprsr_md.drop_ctl = 1;
    }

    table local_forward {
        key = {
            hdr.ipv4.dst_addr : lpm;
        }
        actions = {
            forward_local;
            local_forward_miss;
        }
        const default_action = local_forward_miss;
        size = 64;
    }

    // -------------------------------------------------------------------------
    // Table 4: ECMP 上行表（逻辑 Edge + 5-tuple hash → 上行端口）
    // 用于：跨 Edge 流量，ECMP 选择 Spine1 或 Spine2
    // -------------------------------------------------------------------------
    Hash<bit<16>>(HashAlgorithm_t.CRC16) ecmp_hash;
    ActionSelector(256, ecmp_hash, SelectorMode_t.FAIR) clos_ecmp_selector;

    action set_uplink(PortId_t port, mac_addr_t spine_mac, mac_addr_t edge_mac) {
        egress_port = port;
        hdr.ethernet.dst_addr = spine_mac;
        hdr.ethernet.src_addr = edge_mac;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action ecmp_miss() {
        // Drop the packet
        ig_dprsr_md.drop_ctl = 1;
    }

    table ecmp_uplink {
        key = {
            ig_md.src_edge : exact;
            // 5-tuple hash fields
            lkp.ipv4_src_addr : selector;
            lkp.ipv4_dst_addr : selector;
            lkp.ip_proto : selector;
            lkp.l4_src_port : selector;
            lkp.l4_dst_port : selector;
        }
        actions = {
            set_uplink;
            ecmp_miss;
        }
        const default_action = ecmp_miss;
        size = 256;
        implementation = clos_ecmp_selector;
    }

    // -------------------------------------------------------------------------
    // Apply: Clos 转发逻辑
    // -------------------------------------------------------------------------
    apply {
        // 1. 获取入端口信息（逻辑 Edge + 端口类型）
        port_to_edge.apply();

        // 只处理 IPv4 流量
        if (!hdr.ipv4.isValid()) {
            return;
        }

        // 2. 获取目的 Edge
        dst_to_edge.apply();

        // 3. 转发决策
        if (ig_md.port_type == PORT_TYPE_DOWNLINK) {
            // 从主机来的包
            if (ig_md.src_edge == ig_md.dst_edge && ig_md.dst_edge != EDGE_INVALID) {
                // 同 Edge 内，直接转发
                local_forward.apply();
            } else {
                // 跨 Edge，ECMP 到 Spine
                ecmp_uplink.apply();
            }
        } else if (ig_md.port_type == PORT_TYPE_UPLINK) {
            // 从 Spine 来的包，转发到本地主机
            local_forward.apply();
        }
    }
}

control SwitchIngress(
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    PortMapping(1024, 1024) port_mapping;
    PktValidation() pkt_validation;
    MAC(1024) mac;
    FIB(1024, 1024) fib;
    Nexthop(1024) nexthop;
    LAG() lag;
    ClosForwarding() clos;  // Clos 拓扑转发

    lookup_fields_t lkp;

    action do_arp_reply(mac_addr_t my_mac) {
        mac_addr_t temp_mac = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = my_mac;

        hdr.arp.oper = ARP_REPLY;
        mac_addr_t temp_sha = hdr.arp.sha;
        ipv4_addr_t temp_spa = hdr.arp.spa;

        hdr.arp.sha = my_mac;              // 发送者硬件地址 = 交换机的MAC
        hdr.arp.spa = hdr.arp.tpa;         // 发送者协议地址 = 请求的目标IP
        hdr.arp.tha = temp_sha;            // 目标硬件地址 = 请求者的MAC
        hdr.arp.tpa = temp_spa;            // 目标协议地址 = 请求者的IP
    }

    table arp_reply_table {
        key = {
            hdr.arp.tpa : exact;   // target protocol address
        }
        actions = {
            do_arp_reply;
            NoAction;
        }
        const default_action = NoAction;
        size = 32;
    }

//-----------------------------------------------------------------------------
// Destination MAC lookup
// - Route the packet if the destination MAC address is owned by the switch.
//-----------------------------------------------------------------------------
    action rmac_hit() { }
    table rmac {
        key = {
            lkp.mac_dst_addr : exact;
        }

        actions = {
            NoAction;
            rmac_hit;
        }

        const default_action = NoAction;
        size = 1024;
    }

    apply {
        // Process ARP requests.
        if (hdr.arp.isValid() && hdr.arp.oper == ARP_REQUEST) {
            if (arp_reply_table.apply().hit) {
                ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
                return;
            }
        }

        // Validate packet and extract lookup fields (including L4 ports)
        pkt_validation.apply(hdr, lkp);

        // =================================================================
        // Clos Topology Forwarding (优先处理)
        // 如果是 Clos 拓扑端口的 IPv4 流量，使用 Clos 转发逻辑
        // =================================================================
        clos.apply(lkp, hdr, ig_md, ig_intr_md.ingress_port, ig_tm_md.ucast_egress_port, ig_dprsr_md);
        
        // 如果 Clos 转发设置了出端口，则跳过原有路由逻辑
        if (ig_md.port_type != PORT_TYPE_UNKNOWN) {
            return;
        }

        // =================================================================
        // 原有路由逻辑（用于非 Clos 端口的流量）
        // =================================================================
        port_mapping.apply(ig_intr_md.ingress_port, ig_md);
        switch (rmac.apply().action_run) {
            rmac_hit : {
                if (!BYPASS(L3)) {
                    if (lkp.ip_version == 4w4) {
                        fib.apply(lkp.ipv4_dst_addr, ig_md.vrf, ig_md.nexthop);
                    }
                }
            }
        }

        nexthop.apply(lkp, hdr, ig_md);
        if (!BYPASS(L2)) {
            mac.apply(hdr.ethernet.dst_addr, ig_md.bd, ig_md.egress_ifindex);
        }

        lag.apply(lkp, ig_md.egress_ifindex, ig_tm_md.ucast_egress_port);
    }
}

control SwitchEgress(
        inout header_t hdr,
        inout egress_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport) {

    apply {
        // Empty for now - all processing done in ingress
    }
}

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         SwitchEgressParser(),
         SwitchEgress(),
         SwitchEgressDeparser()) pipe;

Switch(pipe) main;
