#ifndef _CLOS_FORWARDING_P4_
#define _CLOS_FORWARDING_P4_

control ClosForwarding(
        in lookup_fields_t lkp,
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in PortId_t ingress_port,
        inout PortId_t egress_port,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

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

    action forward_local(PortId_t port, mac_addr_t dst_mac, mac_addr_t src_mac) {
        egress_port = port;
        hdr.ethernet.dst_addr = dst_mac;
        hdr.ethernet.src_addr = src_mac;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action local_forward_miss() {
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

    Hash<bit<16>>(HashAlgorithm_t.CRC16) ecmp_hash;
    ActionSelector(256, ecmp_hash, SelectorMode_t.FAIR) clos_ecmp_selector;

    action set_uplink(PortId_t port, mac_addr_t spine_mac, mac_addr_t edge_mac) {
        egress_port = port;
        hdr.ethernet.dst_addr = spine_mac;
        hdr.ethernet.src_addr = edge_mac;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action ecmp_miss() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table ecmp_uplink {
        key = {
            ig_md.src_edge : exact;
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

    apply {
        port_to_edge.apply();

        if (!hdr.ipv4.isValid()) {
            return;
        }

        dst_to_edge.apply();

        if (ig_md.port_type == PORT_TYPE_DOWNLINK) {
            if (ig_md.src_edge == ig_md.dst_edge && ig_md.dst_edge != EDGE_INVALID) {
                local_forward.apply();
            } else {
                ecmp_uplink.apply();
            }
        } else if (ig_md.port_type == PORT_TYPE_UPLINK) {
            local_forward.apply();
        }
    }
}

#endif /* _CLOS_FORWARDING_P4_ */

