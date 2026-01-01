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

