#ifndef _FLOWLET_TNA_INGRESS_PARSER_P4_
#define _FLOWLET_TNA_INGRESS_PARSER_P4_

parser TofinoIngressParser(
        packet_in pkt,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        transition select(ig_intr_md.resubmit_flag) {
            1 : parse_resubmit;
            0 : parse_port_metadata;
        }
    }

    state parse_resubmit {
        transition reject;
    }

    state parse_port_metadata {
        pkt.advance(PORT_METADATA_SIZE);
        transition accept;
    }
}

parser SwitchIngressParser(
        packet_in pkt,
        out header_t hdr,
        out ingress_metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    Checksum() ipv4_checksum;
    TofinoIngressParser() tofino_parser;

    state start {
        ig_md.my_mac = 0;
        ig_md.my_ip = 0;
        ig_md.arp_handled = 1w0;
        ig_md.l4_src_port = 0;
        ig_md.l4_dst_port = 0;
        ig_md.flow_hash = 0;
        ig_md.current_timestamp = 0;
        ig_md.is_new_flowlet = 1w0;
        ig_md.flowlet_id = 0;
        ig_md.ecmp_group_id = 0;

        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
            ETHERTYPE_ARP  : parse_arp;
            default        : accept;
        }
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        ipv4_checksum.add(hdr.ipv4);
        // Ignore checksum_err for now; keep minimal pipeline.
        transition select(hdr.ipv4.protocol) {
            IP_PROTOCOLS_TCP : parse_tcp;
            IP_PROTOCOLS_UDP : parse_udp;
            default          : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition accept;
    }
}

#endif /* _FLOWLET_TNA_INGRESS_PARSER_P4_ */


