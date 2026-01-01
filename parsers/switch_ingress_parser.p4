#ifndef _SWITCH_INGRESS_PARSER_P4_
#define _SWITCH_INGRESS_P4_

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
        // Initialize all metadata fields to avoid uninitialized warnings
        ig_md.checksum_err = false;
        ig_md.bd = 0;
        ig_md.vrf = 0;
        ig_md.nexthop = 0;
        ig_md.ifindex = 0;
        ig_md.egress_ifindex = 0;
        ig_md.bypass = 0;
        ig_md.src_edge = 0;
        ig_md.dst_edge = 0;
        ig_md.port_type = 0;
        ig_md.flow_hash = 0;
        ig_md.current_timestamp = 0;
        ig_md.last_seen_timestamp = 0;
        ig_md.flowlet_gap = 0;
        ig_md.flowlet_id = 0;
        ig_md.is_new_flowlet = false;
        ig_md.selected_path = 0;

        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
            ETHERTYPE_ARP : parse_arp;
            default : accept;
        }
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        ipv4_checksum.add(hdr.ipv4);
        ig_md.checksum_err = ipv4_checksum.verify();
        transition select(hdr.ipv4.protocol) {
            IP_PROTOCOLS_TCP : parse_tcp;
            IP_PROTOCOLS_UDP : parse_udp;
            default : accept;
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

#endif /* _SWITCH_INGRESS_PARSER_P4_ */

