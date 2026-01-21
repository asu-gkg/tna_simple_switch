const bit<32> FLOWLET_TIMEOUT = 150000 >> 8; // 150μs (以 256ns 为单位)
const bit<32> TIMEOUT1 = 200000000 >> 8; // 200ms (以 256ns 为单位)

#define REGISTER_SIZE 65536
typedef bit<16> flow_idx_t;
typedef bit<16> flowlet_id_t;
typedef bit<32> timestamp_t;

#define ECMP_GROUP_SIZE 2

typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;

typedef bit<16> ether_type_t;
const ether_type_t ETHERTYPE_IPV4 = 16w0x0800;
const ether_type_t ETHERTYPE_ARP = 16w0x0806;

typedef bit<16> arp_oper_t;
const arp_oper_t ARP_REQUEST = 16w1;   // ARP 请求
const arp_oper_t ARP_REPLY = 16w2;     // ARP 响应

typedef bit<8> ip_protocol_t;
const ip_protocol_t IP_PROTOCOLS_ICMP = 1;
const ip_protocol_t IP_PROTOCOLS_IPV4 = 4;
const ip_protocol_t IP_PROTOCOLS_TCP = 6;
const ip_protocol_t IP_PROTOCOLS_UDP = 17;

header ethernet_h {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16> ether_type;
}

header arp_h {
    bit<16> htype;      // 1 = Ethernet
    bit<16> ptype;      // 0x0800 = IPv4
    bit<8>  hlen;       // 6
    bit<8>  plen;       // 4
    bit<16> oper;       // 1=request, 2=reply
    mac_addr_t sha;     // sender hardware addr
    ipv4_addr_t spa;    // sender protocol addr
    mac_addr_t tha;     // target hardware addr
    ipv4_addr_t tpa;    // target protocol addr
}

header ipv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> total_len;
    bit<16> identification;
    bit<3> flags;
    bit<13> frag_offset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdr_checksum;
    ipv4_addr_t src_addr;
    ipv4_addr_t dst_addr;
}

header tcp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<32> seq_no;
    bit<32> ack_no;
    bit<4> data_offset;
    bit<4> res;
    bit<8> flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header udp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> hdr_length;
    bit<16> checksum;
}

header icmp_h {
    bit<8> type_;
    bit<8> code;
    bit<16> hdr_checksum;
}

header resubmit_h {
    timestamp_t ts_start;
    bit<16> ingress_port;
    bit<8> ecmp_idx;
    bit<8> qos;
}
