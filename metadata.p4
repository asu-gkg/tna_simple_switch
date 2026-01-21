struct ingress_metadata_t {
    bool checksum_err;

    // L4 header fields
    bit<16> l4_src_port;
    bit<16> l4_dst_port;

    PortId_t ingress_port;

    bit<16> flow_idx;
    bit<16> flowlet_id;
    bit<1> is_new_flowlet;
    bit<1> update_ts_start;
    timestamp_t ts_now;
    timestamp_t gap;
    timestamp_t ts_computation;
    timestamp_t ts_start;
    timestamp_t ts_communication;

    bit<1> reset_qos;
    bit<1> inc_qos;
    bit<5> qos;
    bit<16> ecmp_idx;
    bit<8> qos_op;

    // resubmit data
    resubmit_h resubmit_data;
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
