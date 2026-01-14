#include "arp.p4"
typedef bit<6> exp_t; 

struct qos_t {
    bit<8> qos_op;
    bit<8> qos;
};

control SwitchIngress(
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    ARPControl() arp_control;
    Register<timestamp_t, flow_idx_t>(REGISTER_SIZE) reg_prev;
    Register<timestamp_t, flow_idx_t>(REGISTER_SIZE) reg_prev1;
    Register<timestamp_t, flow_idx_t>(REGISTER_SIZE) reg_prev2;
    Register<timestamp_t, flow_idx_t>(REGISTER_SIZE) reg_start;
    Register<timestamp_t, flow_idx_t>(REGISTER_SIZE) reg_computation;
    Register<flowlet_id_t, flow_idx_t>(REGISTER_SIZE) reg_flowlet_id;
    Register<qos_t, flow_idx_t>(REGISTER_SIZE) reg_qos_state;
    
    Hash<flow_idx_t>(HashAlgorithm_t.CRC16) hash_flow_idx;
    Hash<bit<16>>(HashAlgorithm_t.CRC16) hash_flowlet_id;

    timestamp_t ts_communication;
    timestamp_t ts_computation;

    exp_t exp_comm;
    exp_t exp_comp;

    RegisterAction<timestamp_t, flow_idx_t, bit<1>>(reg_prev) reg_action_prev = {
        void apply(inout timestamp_t last_seen_ts, out bit<1> is_new_flowlet) {
            timestamp_t gap = ig_md.ts_now - last_seen_ts;
            if (last_seen_ts == 0) {
                is_new_flowlet = 1;
            } else if (gap > FLOWLET_TIMEOUT) {
                is_new_flowlet = 1;
            } else {
                is_new_flowlet = 0;
            }
            last_seen_ts = ig_md.ts_now;
        }
    };

    RegisterAction<timestamp_t, flow_idx_t, bit<1>>(reg_prev1) reg_action_prev1 = {
        void apply(inout timestamp_t last_seen_ts, out bit<1> reset_qos) {
            timestamp_t gap = ig_md.ts_now - last_seen_ts;
            if (last_seen_ts == 0) {
                reset_qos = 1;
            } else if (gap > TIMEOUT1) {
                reset_qos = 1;
            } else {
                reset_qos = 0;
            }
            last_seen_ts = ig_md.ts_now;
        }
    };

    RegisterAction<timestamp_t, flow_idx_t, timestamp_t>(reg_prev2) reg_action_prev2 = {
        void apply(inout timestamp_t last_seen_ts, out timestamp_t gap) {
            if (last_seen_ts == 0) {
                gap = 0;
            } else {
                gap = ig_md.ts_now - last_seen_ts;
            }
            last_seen_ts = ig_md.ts_now;
        }
    };

    RegisterAction<timestamp_t, flow_idx_t, timestamp_t>(reg_computation) reg_action_computation = {
        void apply(inout timestamp_t v, out timestamp_t ret_val) {
            if (v == 0) {
                v = TIMEOUT1;
            }
            if (ig_md.gap > TIMEOUT1) {
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

    RegisterAction<timestamp_t, flow_idx_t, timestamp_t>(reg_start) reg_action_start = {
        void apply(inout timestamp_t value, out timestamp_t ret_val) {
            // 第一次pass: resubmit_data.ts_start == 0, 只读取
            // 第二次pass: resubmit_data.ts_start != 0, 写入新值
            if (ig_md.resubmit_data.ts_start != 0) {
                value = ig_md.resubmit_data.ts_start;
            }
            ret_val = value;
        }
    };

    RegisterAction<qos_t, flow_idx_t, bit<8>>(reg_qos_state) reg_action_qos_state = {
        void apply(inout qos_t v, out bit<8> ret) {
            if (v.qos_op == 1) {
                v.qos = 0;
            } else if (v.qos_op == 2) {
                v.qos = v.qos + 1;
            }
            ret = v.qos;
            v.qos_op = ig_md.qos_op;
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

    action set_exp_comm(exp_t e) { exp_comm = e; }
    action set_exp_comp(exp_t e) { exp_comp = e; }

    table msb_comm_table {
        key = { ig_md.ts_communication : ternary; }
        actions = { set_exp_comm; }
        size = 40;
        default_action = set_exp_comm(32);
    }

    table msb_comp_table {
        key = { ig_md.ts_computation : ternary; }
        actions = { set_exp_comp; }
        size = 40;
        default_action = set_exp_comp(32);
    }

    action set_inc(bit<1> v) {
        ig_md.inc_qos = v;
    }

    table cmp_exp_table {
        key = {
            exp_comm : exact;
            exp_comp : exact;
        }
        actions = {
            set_inc;
        }
        size = 1024;              // 32*32
        default_action = set_inc(0);
    }

    apply {
        // arp control
        if (hdr.arp.isValid() && hdr.arp.oper == ARP_REQUEST) {
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
        
        ig_md.ts_now = (timestamp_t) ig_intr_md.ingress_mac_tstamp[39:8]; // 256ns 颗粒度

        ig_md.flow_idx = hash_flow_idx.get(
            {
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.ipv4.protocol,
                ig_md.l4_src_port,
                ig_md.l4_dst_port
            }
        );

        // 同一control下寄存器操作只能进行一次，因此需要先取ts_start;
        // 若需要更新，则在second pass中进行
        timestamp_t ts_start = reg_action_start.execute(ig_md.flow_idx); 

        if (ig_intr_md.resubmit_flag == 1) {
            // second pass
            return;
        }

        // first pass
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

        /*** 
        if (ts_prev == 0) {
            ig_md.is_new_flowlet = 1w1;
            ig_md.gap = 0;
        } else {
            ig_md.gap = ig_md.ts_now - ts_prev;
        }
        ***/
        ig_md.is_new_flowlet = reg_action_prev.execute(ig_md.flow_idx);
        ig_md.reset_qos = reg_action_prev1.execute(ig_md.flow_idx);

        ig_md.gap = reg_action_prev2.execute(ig_md.flow_idx);

        // ✅ 2, 3
        /*** 2. compute gap
        // if (ts_prev != 0) {
        //     ig_md.gap = ig_md.ts_now - ts_prev;
        // } else {
        //     ig_md.is_new_flowlet = 1w1;
        // }

        // // 3. reset_qos and is_new_flowlet? 
        // if (ig_md.gap > TIMEOUT1) {
        //     ig_md.reset_qos = 1w1;
        // } else {
        //     ig_md.reset_qos = 1w0;
        // }
        
        // if (ts_prev == 0 || ig_md.gap > FLOWLET_TIMEOUT) {
        //     ig_md.is_new_flowlet = 1w1;
        // } else {
        //     ig_md.is_new_flowlet = 1w0;
        // } 
        ***/

        // 4. compute T_Computation, depends on gap
        ig_md.ts_computation = reg_action_computation.execute(ig_md.flow_idx);

        // // 5. update flowlet_id
        ig_md.flowlet_id = reg_action_flowlet_id.execute(ig_md.flow_idx);

        // // 6. update ts_start, depends on is_new_flowlet 
        // // and whether duration of communication is greater than T_Computation
        // 7. compute ts_communication
        // timestamp_t ts_start = reg_action_start.execute(ig_md.flow_idx);

        ig_md.ts_computation = ig_md.ts_computation;
        
        ig_md.ts_communication = ig_md.ts_now - ts_start;

        msb_comm_table.apply();
        msb_comp_table.apply();

        cmp_exp_table.apply();
        
        // // 8. compute inc_qos
        // if (ig_md.reset_qos == 1w0) {
        //     if (ig_md.is_new_flowlet == 1w0 && ts_communication > ig_md.ts_computation) {
        //         ig_md.inc_qos = 1w1;
        //     }
        //     // ig_md.inc_qos = (ig_md.is_new_flowlet == 1w0 && ts_communication > ig_md.ts_computation) ? 1w1 : 1w0;
        // } else {
        //     ig_md.inc_qos = 1w0;
        // }

        // // update qos
        // ig_md.qos = reg_action_qos.execute(ig_md.flow_idx);

        // qos_op: 1 = reset, 2 = increment
        ig_md.qos_op = 0;
        if (ig_md.reset_qos == 1w1) {
            ig_md.qos_op = 1;
        } else if (ig_md.inc_qos == 1w1) {
            ig_md.qos_op = 2;
        }

        bit<8> qos = reg_action_qos_state.execute(ig_md.flow_idx);
        if (qos > 31) {
            ig_md.qos = 31;
        } else {
            ig_md.qos = (QueueId_t) qos;
        }

        // impl flowlet switching
        ig_md.ecmp_idx = ig_md.flowlet_id & (ECMP_GROUP_SIZE - 1);
        downlink_to_uplink_port.apply();
        ig_tm_md.qid = (QueueId_t) ig_md.qos;

        // 判断是否需要更新ts_start：is_new_flowlet或inc_qos
        // 如果需要，触发resubmit在第二次pass中更新寄存器
        if (ig_md.qos_op != 0) {
            ig_md.resubmit_data.ts_start = ig_md.ts_now;
            ig_dprsr_md.resubmit_type = 1;
        }
    }
}