#ifndef _METADATA_P4_
#define _METADATA_P4_

typedef bit<16> bd_t;
typedef bit<16> vrf_t;
typedef bit<16> nexthop_t;
typedef bit<16> ifindex_t;

typedef bit<8> bypass_t;
const bypass_t BYPASS_L2 = 8w0x01;
const bypass_t BYPASS_L3 = 8w0x02;
const bypass_t BYPASS_ACL = 8w0x04;
const bypass_t BYPASS_ALL = 8w0xff;
#define BYPASS(t) (ig_md.bypass & BYPASS_##t != 0)

typedef bit<8> edge_id_t;
const edge_id_t EDGE_INVALID = 0;
const edge_id_t EDGE_1 = 1;
const edge_id_t EDGE_2 = 2;
const edge_id_t EDGE_3 = 3;
const edge_id_t EDGE_4 = 4;

typedef bit<2> port_type_t;
const port_type_t PORT_TYPE_UNKNOWN = 0;
const port_type_t PORT_TYPE_DOWNLINK = 1;
const port_type_t PORT_TYPE_UPLINK = 2;

// Flowlet相关常量和类型
const bit<48> FLOWLET_TIMEOUT = 64000; // 64μs (以纳秒为单位)
typedef bit<32> flow_hash_t;
typedef bit<16> flowlet_id_t;
typedef bit<8> path_id_t;

struct ingress_metadata_t {
    bool checksum_err;
    bd_t bd;
    vrf_t vrf;
    nexthop_t nexthop;
    ifindex_t ifindex;
    ifindex_t egress_ifindex;
    bypass_t bypass;
    edge_id_t src_edge;
    edge_id_t dst_edge;
    port_type_t port_type;

    // Flowlet相关字段
    flow_hash_t flow_hash;           // flow标识hash
    bit<48> current_timestamp;       // 当前包时间戳
    bit<48> last_seen_timestamp;     // 该flow上次包时间戳
    bit<48> flowlet_gap;            // 包间隔时间
    flowlet_id_t flowlet_id;        // 当前flowlet ID
    bool is_new_flowlet;            // 是否新flowlet
    path_id_t selected_path;        // 选择的路径ID
}

struct egress_metadata_t {
    // Reserved for future use.
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
    bit<16> l4_src_port;
    bit<16> l4_dst_port;
}

struct header_t {
    ethernet_h ethernet;
    ipv4_h ipv4;
    arp_h arp;
    tcp_h tcp;
    udp_h udp;
}

#endif /* _METADATA_P4_ */

