#include "arp.p4"


control SwitchIngress(
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    ARPControl() arp_control;

    Register<timestamp_t, flow_idx_t>(REGISTER_SIZE) reg_prev;
    Register<timestamp_t, flow_idx_t>(REGISTER_SIZE) reg_start;
    Register<timestamp_t, flow_idx_t>(REGISTER_SIZE) reg_computation;
    Register<flowlet_id_t, flow_idx_t>(REGISTER_SIZE) reg_flowlet_id;
    Register<bit<32>, flow_idx_t>(REGISTER_SIZE) reg_qos;
    
    Hash<flow_idx_t>(HashAlgorithm_t.CRC16) hash_flow_idx;
    Hash<flowlet_id_t>(HashAlgorithm_t.CRC16) hash_flowlet_id;

    RegisterAction<timestamp_t, flow_idx_t, timestamp_t>(reg_prev) reg_action_prev = {
        void apply(inout timestamp_t v, out timestamp_t ret_val) {
            ret_val =  v;
            v = ig_md.ts_now;
        }
    };

    RegisterAction<timestamp_t, flow_idx_t, timestamp_t>(reg_start) reg_action_start = {
        void apply(inout timestamp_t v, out timestamp_t ret_val) {
            ret_val = v;
            
            timestamp_t duration = ig_md.ts_now - v;
            bool is_timeout = (duration > ig_md.ts_computation);
            if (ig_md.is_new_flowlet == 1w1 || is_timeout) {
                v = ig_md.ts_now;
            }
        }
    };

    RegisterAction<timestamp_t, flow_idx_t, timestamp_t>(reg_computation) reg_action_computation = {
        void apply(inout timestamp_t v, out timestamp_t ret_val) {
            if (v == 0) {
                v = TIMEOUT1;
            }
            // 使用 reset_qos 标志位代替 ig_md.gap > TIMEOUT1 判断
            if (ig_md.reset_qos == 1w1) {
                v = ig_md.gap;
            }
            ret_val = v;
        }
    };

    RegisterAction<flowlet_id_t, flow_idx_t, flowlet_id_t>(reg_flowlet_id) reg_action_flowlet_id = {
        void apply(inout flowlet_id_t v, out flowlet_id_t ret_val) {
            if (ig_md.is_new_flowlet == 1w1) {
                v = ig_md.flowlet_id;
            } 
            ret_val = v;
        }
    };

    RegisterAction<QueueId_t, flow_idx_t, QueueId_t>(reg_qos) reg_action_qos = {
        void apply(inout QueueId_t v, out QueueId_t ret_val) {
            if (ig_md.reset_qos == 1w1) {
                v = 0;
            }  
            if (ig_md.inc_qos == 1w1) {
                v = v + 1;
            }
            ret_val = v;
        }
    };

    // RegisterAction<flowlet_state_t, flow_idx_t, flowlet_state_t>(flow_to_flowlet) reg_action_flowlet = {
    //     void apply(inout flowlet_state_t flowlet_state, out flowlet_state_t old_val) {
    //         old_val = flowlet_state;

    //         // 首包兜底
    //         if (flowlet_state.ts_prev == 0 || flowlet_state.ts_start == 0) {
    //             flowlet_state.ts_prev = ig_md.ts_now;
    //             flowlet_state.ts_start = ig_md.ts_now;
    //             flowlet_state.flowlet_id = ig_md.flowlet_id;
    //             flowlet_state.ts_computation = TIMEOUT1;
    //             flowlet_state.qos = 0;
    //             ig_md.ts_computation = TIMEOUT1;
    //             ig_md.ts_communication = 0;
    //             ig_md.qos = 0;
    //             return;
    //         }

    //         timestamp_t gap = ig_md.ts_now - flowlet_state.ts_prev;
    //         ig_md.ts_computation = flowlet_state.ts_computation;
            
    //         if (gap > TIMEOUT1) {
    //             ig_md.ts_computation = gap;
    //             flowlet_state.ts_computation = gap;
    //             flowlet_state.qos = 0;
    //         }
    //         if (gap > FLOWLET_TIMEOUT) {
    //             ig_md.ts_communication = 0;
    //             flowlet_state.ts_start = ig_md.ts_now;
    //             ig_md.is_new_flowlet = 1w1;
    //             flowlet_state.flowlet_id = ig_md.flowlet_id;
    //         } else {
    //             ig_md.ts_communication = ig_md.ts_now - flowlet_state.ts_start;
    //         }

    //         if (ig_md.ts_communication > ig_md.ts_computation) {
    //             // option
    //             // if (flowlet_state.qos != 5w31) {
    //             //     flowlet_state.qos = flowlet_state.qos + 1;
    //             // }
    //             flowlet_state.qos = flowlet_state.qos + 1;
    //             flowlet_state.ts_start = ig_md.ts_now;
    //         }

    //         ig_md.qos = flowlet_state.qos;
    //         ig_md.flowlet_id = flowlet_state.flowlet_id;
    //         flowlet_state.ts_prev = ig_md.ts_now;
    //     }
    // };

    action set_nhop(mac_addr_t dmac, PortId_t port) {
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = dmac;
        ig_tm_md.ucast_egress_port = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
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

    action set_reset_qos() {
        ig_md.reset_qos = 1w1;
    }

    action clear_reset_qos() {
        ig_md.reset_qos = 1w0;
    }

    table check_gap_timeout1 {
        key = {
            ig_md.gap : range;
        }
        actions = {
            set_reset_qos;
            clear_reset_qos;
        }
        const entries = {
            TIMEOUT1 .. 0xFFFFFFFF : set_reset_qos();
        }
        const default_action = clear_reset_qos();
        size = 2;
    }

    action set_new_flowlet() {
        ig_md.is_new_flowlet = 1w1;
    }

    action clear_new_flowlet() {
        ig_md.is_new_flowlet = 1w0;
    }

    // 用表来判断 ts_prev == 0 || gap > FLOWLET_TIMEOUT
    table check_new_flowlet {
        key = {
            ig_md.ts_prev : ternary;
            ig_md.gap : range;
        }
        actions = {
            set_new_flowlet;
            clear_new_flowlet;
        }
        const entries = {
            // ts_prev == 0 时，无论 gap 是多少都是 new flowlet
            (0, 0 .. 0xFFFFFFFF) : set_new_flowlet();
            // ts_prev != 0 但 gap > FLOWLET_TIMEOUT 时是 new flowlet
            (_, FLOWLET_TIMEOUT+1 .. 0xFFFFFFFF) : set_new_flowlet();
        }
        const default_action = clear_new_flowlet();
        size = 4;
    }

    action set_inc_qos() {
        ig_md.inc_qos = 1w1;
    }

    action clear_inc_qos() {
        ig_md.inc_qos = 1w0;
    }

    // 用表判断 is_new_flowlet == 0 && ts_communication > ts_computation
    // 通过检查 comm_minus_comp (= ts_communication - ts_computation) 来判断
    // 如果差值在 (0, 0x7FFFFFFF] 范围内，说明 ts_communication > ts_computation
    table check_inc_qos {
        key = {
            ig_md.reset_qos : exact;
            ig_md.is_new_flowlet : exact;
            ig_md.comm_minus_comp : range;
        }
        actions = {
            set_inc_qos;
            clear_inc_qos;
        }
        const entries = {
            // reset_qos == 0, is_new_flowlet == 0, comm_minus_comp > 0 且没有溢出
            (0, 0, 1 .. 0x7FFFFFFF) : set_inc_qos();
        }
        const default_action = clear_inc_qos();
        size = 4;
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
        ig_md.flow_idx = hash_flow_idx.get(
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
        ig_md.flowlet_id = hash_flowlet_id.get(
            {
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.ipv4.protocol,
                ig_md.l4_src_port,
                ig_md.l4_dst_port,
                ig_md.ts_now
            }
        );

        // 1. get old prev and update it
        timestamp_t ts_prev = reg_action_prev.execute(ig_md.flow_idx);

        // 2. compute gap
        if (ig_md.ts_prev == 0) {
            ig_md.gap = 0;
        } else {
            ig_md.gap = ig_md.ts_now - ig_md.ts_prev;
        }

        // 3. reset_qos and is_new_flowlet? 
        // 使用表来判断复杂条件，避免 "condition too complex" 错误
        check_gap_timeout1.apply();
        check_new_flowlet.apply();

        // 4. compute T_Computation, depends on gap
        timestamp_t ts_computation = reg_action_computation.execute(ig_md.flow_idx);
        ig_md.ts_computation = ts_computation;

        // 5. update flowlet_id
        ig_md.flowlet_id = reg_action_flowlet_id.execute(ig_md.flow_idx);

        // 6. update ts_start, depends on is_new_flowlet 
        // and whether duration of communication is greater than T_Computation
        timestamp_t ts_start = reg_action_start.execute(ig_md.flow_idx);

        // 7. compute ts_communication

        // ig_md.ts_communication = (ts_prev == 0) ? 0 : (ig_md.ts_now - ts_start);
        ig_md.ts_communication = ig_md.ts_now - ts_start;
        if (ts_prev == 0) {
            ig_md.ts_communication = 0;
        }
        
        // 8. compute inc_qos
        // 计算差值用于表判断 (ts_communication > ts_computation)
        ig_md.comm_minus_comp = ig_md.ts_communication - ig_md.ts_computation;
        // 使用表来判断复杂条件，避免 "condition too complex" 错误
        check_inc_qos.apply();

        // update qos
        ig_md.qos = reg_action_qos.execute(ig_md.flow_idx);

        // impl flowlet switching
        ig_md.ecmp_idx = ig_md.flowlet_id & (ECMP_GROUP_SIZE - 1);
        if (!downlink_to_uplink_port.apply().hit) {
            drop();
            return;
        }

        ig_tm_md.qid = (QueueId_t) ig_md.qos;
    }
}