
const bit<48> FLOWLET_TIMEOUT = 640000; // 640μs (以纳秒为单位)
const bit<48> TIMEOUT1 = 1000000000; // 1s

#define REGISTER_SIZE 65536
typedef bit<16> flow_idx_t;
typedef bit<16> flowlet_id_t;
typedef bit<48> timestamp_t;

#define ECMP_GROUP_SIZE 2

struct ingress_metadata_t {
    // L4 header fields
    bit<16> l4_src_port;
    bit<16> l4_dst_port;

    bit<16> flow_idx;
    bit<16> flowlet_id;
    bit<1> is_new_flowlet;
    timestamp_t ts_now;

    timestamp_t ts_computation;
    timestamp_t ts_communication;
    bit<5> qos;
    bit<16> ecmp_idx;
}

struct flowlet_state_t {
    timestamp_t   ts_prev;
    timestamp_t   ts_start;
    timestamp_t   ts_computation;
    flowlet_id_t  flowlet_id;
    bit<5> qos;
}

struct egress_metadata_t {
    // Reserved for future use.
}

struct header_t {
    ethernet_h ethernet;
    ipv4_h ipv4;
    arp_h arp;
    tcp_h tcp;
    udp_h udp;
}