#ifndef _FLOWLET_TNA_INGRESS_P4_
#define _FLOWLET_TNA_INGRESS_P4_

control SwitchIngress(
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    // === Flow hash ===
    Hash<bit<32>>(HashAlgorithm_t.CRC32) flow_hash_calc;

    // === Flowlet state registers ===
    Register<bit<32>, flow_hash_t>(FLOW_STATE_SIZE) last_seen_ts;
    Register<flowlet_id_t, flow_hash_t>(FLOW_STATE_SIZE) flowlet_counter;

    RegisterAction<bit<32>, flow_hash_t, bit<1>>(last_seen_ts) check_and_update_flowlet = {
        void apply(inout bit<32> last_ts, out bit<1> is_new) {
            bit<32> gap = ig_md.current_timestamp - last_ts;

            if (last_ts == 0) {
                is_new = 1;
            } else if (gap > FLOWLET_TIMEOUT_NS) {
                is_new = 1;
            } else {
                is_new = 0;
            }
            last_ts = ig_md.current_timestamp;
        }
    };

    RegisterAction<flowlet_id_t, flow_hash_t, flowlet_id_t>(flowlet_counter) alloc_flowlet_id = {
        void apply(inout flowlet_id_t v, out flowlet_id_t result) {
            v = v + 1;
            result = v;
        }
    };

    // === Clos Topology Tables ===

    // Table 1: Port → Edge mapping
    action set_port_info_clos(edge_id_t edge_id, port_type_t ptype) {
        ig_md.src_edge = edge_id;
        ig_md.port_type = ptype;
    }

    table port_to_edge {
        key = { ig_intr_md.ingress_port : exact; }
        actions = { set_port_info_clos; NoAction; }
        const default_action = NoAction;
        size = 64;
    }

    // Table 2: Destination IP → Edge (LPM)
    action set_dst_edge(edge_id_t edge_id) {
        ig_md.dst_edge = edge_id;
    }

    table dst_to_edge {
        key = { hdr.ipv4.dst_addr : lpm; }
        actions = { set_dst_edge; NoAction; }
        const default_action = NoAction;
        size = 64;
    }

    // Table 3: Local forwarding
    action forward_local(mac_addr_t dmac, PortId_t port) {
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = dmac;
        ig_tm_md.ucast_egress_port = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table local_forward {
        key = { hdr.ipv4.dst_addr : lpm; }
        actions = { forward_local; NoAction; }
        const default_action = NoAction;
        size = 64;
    }

    // Table 4: Clos ECMP uplink (with flowlet integration)
    // Hash for Clos ECMP selector (5-tuple + flowlet_id)
    Hash<bit<16>>(HashAlgorithm_t.CRC16) ecmp_selector_hash;

    ActionProfile(256) clos_ecmp_profile;
    ActionSelector(
        clos_ecmp_profile,
        ecmp_selector_hash,  // Hash for Clos ECMP
        SelectorMode_t.FAIR,
        32w32,   // max_group_size
        32w16    // num_groups (4 edges * 4 max groups)
    ) clos_ecmp_selector;

    action set_uplink(mac_addr_t dmac, PortId_t port) {
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = dmac;
        ig_tm_md.ucast_egress_port = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ecmp_uplink {
        key = {
            ig_md.src_edge : exact;
            // 5-tuple + flowlet_id for consistent routing
            hdr.ipv4.src_addr : selector;
            hdr.ipv4.dst_addr : selector;
            hdr.ipv4.protocol : selector;
            ig_md.l4_src_port : selector;
            ig_md.l4_dst_port : selector;
            ig_md.flowlet_id : selector;  // Key integration point
        }
        actions = { set_uplink; NoAction; }
        const default_action = NoAction;
        size = 256;
        implementation = clos_ecmp_selector;
    }

    // === ARP: per-ingress-port "gateway" info ===
    action set_port_info(mac_addr_t mac, ipv4_addr_t ip) {
        ig_md.my_mac = mac;
        ig_md.my_ip = ip;
    }

    table port_info {
        key = { ig_intr_md.ingress_port : exact; }
        actions = { set_port_info; NoAction; }
        const default_action = NoAction;
        size = 256;
    }

    action do_arp_reply() {
        hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = ig_md.my_mac;
        hdr.ethernet.ether_type = ETHERTYPE_ARP;

        hdr.arp.oper = ARP_REPLY;
        hdr.arp.tha  = hdr.arp.sha;
        hdr.arp.tpa  = hdr.arp.spa;
        hdr.arp.sha  = ig_md.my_mac;
        hdr.arp.spa  = ig_md.my_ip;

        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        ig_md.arp_handled = 1w1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    apply {
        // Initialize Clos metadata
        ig_md.src_edge = 0;
        ig_md.dst_edge = 0;
        ig_md.port_type = PORT_TYPE_UNKNOWN;

        // ARP handling (unchanged)
        if (hdr.arp.isValid()) {
            port_info.apply();
            if (hdr.arp.oper == ARP_REQUEST) {
                if (hdr.arp.tpa == ig_md.my_ip) {
                    do_arp_reply();
                } else {
                    drop();
                }
            } else {
                drop();
            }
            return;
        }

        if (!hdr.ipv4.isValid()) {
            return;
        }

        // Fill L4 ports (TCP/UDP); otherwise 0 (unchanged)
        if (hdr.tcp.isValid()) {
            ig_md.l4_src_port = hdr.tcp.src_port;
            ig_md.l4_dst_port = hdr.tcp.dst_port;
        } else if (hdr.udp.isValid()) {
            ig_md.l4_src_port = hdr.udp.src_port;
            ig_md.l4_dst_port = hdr.udp.dst_port;
        } else {
            ig_md.l4_src_port = 0;
            ig_md.l4_dst_port = 0;
        }

        // Current timestamp (unchanged)
        ig_md.current_timestamp = (bit<32>) ig_intr_md.ingress_mac_tstamp;

        // Compute flow hash (unchanged)
        ig_md.flow_hash = flow_hash_calc.get({
            hdr.ipv4.src_addr,
            hdr.ipv4.dst_addr,
            hdr.ipv4.protocol,
            ig_md.l4_src_port,
            ig_md.l4_dst_port
        });

        // Flowlet processing (unchanged)
        bit<1> new_flowlet = check_and_update_flowlet.execute(ig_md.flow_hash);
        ig_md.is_new_flowlet = new_flowlet;
        if (new_flowlet == 1w1) {
            ig_md.flowlet_id = alloc_flowlet_id.execute(ig_md.flow_hash);
        }

        // === NEW: Clos Topology Forwarding (Full Replacement) ===
        port_to_edge.apply();  // Classify source edge and port type
        dst_to_edge.apply();   // Classify destination edge

        // Conditional forwarding based on Clos logic
        if (ig_md.port_type == PORT_TYPE_DOWNLINK) {
            // From host
            if (ig_md.src_edge == ig_md.dst_edge && ig_md.dst_edge != 0) {
                // Same edge, local forward
                local_forward.apply();
            } else if (ig_md.dst_edge != 0) {
                // Cross-edge, ECMP to spine with flowlet awareness
                ecmp_uplink.apply();
            }
        } else if (ig_md.port_type == PORT_TYPE_UPLINK) {
            // From spine, local forward to destination host
            local_forward.apply();
        }
    }
}

#endif /* _FLOWLET_TNA_INGRESS_P4_ */


