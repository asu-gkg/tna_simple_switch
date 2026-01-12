
const bit<32> FLOWLET_TIMEOUT = 640000; // 640μs (以纳秒为单位)
const bit<32> TIMEOUT1 = 1000000000; // 1s

#define REGISTER_SIZE 65536
typedef bit<16> flow_idx_t;
typedef bit<16> flowlet_id_t;
typedef bit<32> timestamp_t;

#define ECMP_GROUP_SIZE 2

struct ingress_metadata_t {
    bool checksum_err;
    
    // L4 header fields
    bit<16> l4_src_port;
    bit<16> l4_dst_port;

    bit<16> flow_idx;
    bit<16> flowlet_id;
    bit<1> is_new_flowlet;
    timestamp_t ts_now;
    timestamp_t ts_prev;
    timestamp_t gap;
    timestamp_t ts_computation;
    
    bit<1> reset_qos;
    bit<1> inc_qos;
    bit<1> update_ts_start;
    bit<5> qos;
    bit<16> ecmp_idx;

    
    // 用于复杂条件判断
    timestamp_t ts_communication;
    timestamp_t comm_minus_comp;  // ts_communication - ts_computation
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