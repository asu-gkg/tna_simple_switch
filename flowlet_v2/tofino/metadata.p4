#ifndef _FLOWLET_TNA_METADATA_P4_
#define _FLOWLET_TNA_METADATA_P4_

typedef bit<16> ecmp_group_id_t;
typedef bit<16> flowlet_id_t;
typedef bit<32> flow_hash_t;

// Register sizes (tune as needed)
const bit<32> FLOW_STATE_SIZE = 32768;

// 100ms in nanoseconds (Tofino ingress_mac_tstamp is in ns)
const bit<32> FLOWLET_TIMEOUT_NS = 32w100000000;

struct ingress_metadata_t {
    // For ARP reply
    mac_addr_t my_mac;
    ipv4_addr_t my_ip;
    bit<1> arp_handled;

    // L4 ports for hashing (TCP/UDP; otherwise 0)
    bit<16> l4_src_port;
    bit<16> l4_dst_port;

    // Flowlet state
    flow_hash_t flow_hash;
    bit<32> current_timestamp;
    bit<1> is_new_flowlet;
    flowlet_id_t flowlet_id;

    // Routing/ECMP
    ecmp_group_id_t ecmp_group_id;
}

struct egress_metadata_t { }

struct header_t {
    ethernet_h ethernet;
    arp_h      arp;
    ipv4_h     ipv4;
    tcp_h      tcp;
    udp_h      udp;
}

#endif /* _FLOWLET_TNA_METADATA_P4_ */


