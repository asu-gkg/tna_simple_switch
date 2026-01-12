#include "arp.p4"


control SwitchIngress(
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    ARPControl() arp_control;

    Register<flowlet_state_t, flow_idx_t>(REGISTER_SIZE) flow_to_flowlet;

    Hash<flow_idx_t>(HashAlgorithm_t.CRC16) hash;

    RegisterAction<flowlet_state_t, flow_idx_t, flowlet_state_t>(flow_to_flowlet) reg_action_flowlet = {
        void apply(inout flowlet_state_t flowlet_state, out flowlet_state_t old_val) {
            old_val = flowlet_state;
            ig_md.is_new_flowlet = 0w0;

            // 首包兜底
            if (flowlet_state.ts_prev == 0 || flowlet_state.ts_start == 0) {
                flowlet_state.ts_prev = ig_md.ts_now;
                flowlet_state.ts_start = ig_md.ts_now;
                flowlet_state.flowlet_id = ig_md.flowlet_id;
                flowlet_state.ts_computation = TIMEOUT1;
                flowlet_state.qos = 0;
                ig_md.ts_computation = TIMEOUT1;
                ig_md.ts_communication = 0;
                ig_md.is_new_flowlet = 1w1;
                ig_md.qos = 0;
                return;
            }

            timestamp_t gap = ig_md.ts_now - flowlet_state.ts_prev;
            ig_md.ts_computation = flowlet_state.ts_computation;
            
            if (gap > TIMEOUT1) {
                ig_md.ts_computation = gap;
                flowlet_state.ts_computation = gap;
                flowlet_state.qos = 0;
            }
            if (gap > FLOWLET_TIMEOUT) {
                ig_md.ts_communication = 0;
                flowlet_state.ts_start = ig_md.ts_now;
                ig_md.is_new_flowlet = 1w1;
                flowlet_state.flowlet_id = ig_md.flowlet_id;
            } else {
                ig_md.ts_communication = ig_md.ts_now - flowlet_state.ts_start;
            }

            if (ig_md.ts_communication > ig_md.ts_computation) {
                // option
                // if (flowlet_state.qos != 5w31) {
                //     flowlet_state.qos = flowlet_state.qos + 1;
                // }
                flowlet_state.qos = flowlet_state.qos + 1;
                flowlet_state.ts_start = ig_md.ts_now;
            }

            ig_md.qos = flowlet_state.qos;
            ig_md.flowlet_id = flowlet_state.flowlet_id;
            flowlet_state.ts_prev = ig_md.ts_now;
        }
    };

    table ecmp_group_table {
        key = {
            ig_intr_md.ingress_port: exact;
        }
        actions = {
            
            drop;
        }
        const default_action = drop;
        size = 256;
    }

    action set_nhop(mac_addr_t dmac, PortId_t port) {
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = dmac;
        ig_tm_md.ucast_egress_port = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table uplink_port_mac_to_nhop {
        key = {
            ig_intr_md.ingress_port : exact;
            hdr.ethernet.dst_addr   : exact;
        }
        actions = {
            set_nhop;
            NoAction;
        }
        const default_action = NoAction;
        size = 128;
    }

    table downlink_to_uplink_port {
        key = {
            ig_intr_md.ingress_port : exact;
            ig_md.ecmp_idx : exact;
        }
        actions = {
            set_nhop;
            drop;
        }
        const default_action = drop;
        size = 128;
    }

    apply {
        // arp control
        if (hdr.arp.isValid()) {
            arp_control.apply(hdr, ig_intr_md, ig_tm_md);
            return;
        }

        if (!hdr.ipv4.isValid()) {
            return;
        }

        // init metadata
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
        
        ig_md.ts_now = (timestamp_t) ig_intr_md.ingress_mac_tstamp;
        ig_md.flow_idx = hash.get(
            {
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.ipv4.protocol,
                ig_md.l4_src_port,
                ig_md.l4_dst_port
            }
        );

        if (uplink_port_mac_to_nhop.apply().hit) {
            return;
        }

        // init a candidate flowlet_id
        ig_md.flowlet_id = hash.get(
            {
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.ipv4.protocol,
                ig_md.l4_src_port,
                ig_md.l4_dst_port,
                ig_md.ts_now
            }
        );

        reg_action_flowlet.execute(ig_md.flow_idx);

        // impl flowlet switching
        ig_md.ecmp_idx = ig_md.flowlet_id & (ECMP_GROUP_SIZE - 1);
        if (!downlink_to_uplink_port.apply().hit) {
            drop();
            return;
        }

        ig_tm_md.qid = (QueueId_t) ig_md.qos;
    }
}