#ifndef _CLOS_FORWARDING_P4_
#define _CLOS_FORWARDING_P4_

control ClosForwarding(
        in lookup_fields_t lkp,
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in PortId_t ingress_port,
        inout PortId_t egress_port,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        in ingress_intrinsic_metadata_t ig_intr_md) {

    // Flow hash计算器
    Hash<bit<32>>(HashAlgorithm_t.CRC32) flow_hash_calc;

    // Flowlet状态跟踪寄存器
    // 时间戳链路使用 32-bit（取 ingress_mac_tstamp 低 32 位）
    Register<bit<32>, flow_hash_t>(32768) flowlet_last_seen;  // 上次包时间戳（低 32 位）
    Register<flowlet_id_t, flow_hash_t>(32768) flowlet_counter; // flowlet计数器
    Register<path_id_t, flow_hash_t>(32768) flowlet_path;    // 当前路径

    // 检测是否新 flowlet 并更新时间戳
    // 关键：在寄存器内完成超时判断，避免 control 层条件复杂度超限
    RegisterAction<bit<32>, flow_hash_t, bit<1>>(flowlet_last_seen) check_and_update_flowlet = {
        void apply(inout bit<32> last_ts, out bit<1> is_new) {
            bit<32> gap;
            gap = ig_md.current_timestamp - last_ts;
            
            // 首包（last_ts == 0）或超时都是新 flowlet
            if (last_ts == 0) {
                is_new = 1;
            } else if (gap > FLOWLET_TIMEOUT) {
                is_new = 1;
            } else {
                is_new = 0;
            }
            
            // 更新时间戳
            last_ts = ig_md.current_timestamp;
        }
    };

    // 递增flowlet计数器
    RegisterAction<flowlet_id_t, flow_hash_t, flowlet_id_t>(flowlet_counter) increment_flowlet = {
        void apply(inout flowlet_id_t value, out flowlet_id_t result) {
            value = value + 1;
            result = value;
        }
    };

    // 读取已保存路径
    RegisterAction<path_id_t, flow_hash_t, path_id_t>(flowlet_path) read_path = {
        void apply(inout path_id_t value, out path_id_t result) {
            result = value;
        }
    };

    // 保存新选择的路径
    RegisterAction<path_id_t, flow_hash_t, path_id_t>(flowlet_path) write_path = {
        void apply(inout path_id_t value, out path_id_t result) {
            value = ig_md.selected_path;
            result = value;
        }
    };

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

    // Flowlet ECMP hash和selector
    Hash<bit<16>>(HashAlgorithm_t.CRC16) flowlet_ecmp_hash;
    ActionSelector(256, flowlet_ecmp_hash, SelectorMode_t.FAIR) flowlet_ecmp_selector;

    action set_uplink(PortId_t port, mac_addr_t spine_mac, mac_addr_t edge_mac) {
        egress_port = port;
        hdr.ethernet.dst_addr = spine_mac;
        hdr.ethernet.src_addr = edge_mac;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;

        // 记录选择的路径
        ig_md.selected_path = (path_id_t)(port & 0xFF);
    }

    action ecmp_miss() {
        ig_dprsr_md.drop_ctl = 1;
    }

    // 新flowlet的ECMP选择表
    table flowlet_uplink {
        key = {
            ig_md.src_edge : exact;
            ig_md.flow_hash : selector;     // 基于flow hash
            ig_md.flowlet_id : selector;    // 基于flowlet ID
        }
        actions = {
            set_uplink;
            ecmp_miss;
        }
        const default_action = ecmp_miss;
        size = 256;
        implementation = flowlet_ecmp_selector;
    }

    // 基于已保存路径的转发动作
    action forward_saved_path(PortId_t port, mac_addr_t spine_mac, mac_addr_t edge_mac) {
        egress_port = port;
        hdr.ethernet.dst_addr = spine_mac;
        hdr.ethernet.src_addr = edge_mac;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    // 已保存路径的转发表
    table saved_path_uplink {
        key = {
            ig_md.src_edge : exact;
            ig_md.selected_path : exact;
        }
        actions = {
            forward_saved_path;
            ecmp_miss;
        }
        const default_action = ecmp_miss;
        size = 32;
    }

    apply {
        port_to_edge.apply();

        if (!hdr.ipv4.isValid()) {
            return;
        }

        dst_to_edge.apply();

        if (ig_md.port_type == PORT_TYPE_DOWNLINK) {
            if (ig_md.src_edge == ig_md.dst_edge && ig_md.dst_edge != EDGE_INVALID) {
                // 同Edge内转发，无需flowlet检测
                local_forward.apply();
            } else {
                // 跨Edge转发，使用flowlet逻辑

                // Step 1: 执行flowlet检测（在 control apply 中实现，避免 target 对 action 的限制）
                // 计算flow hash (基于5-tuple)
                ig_md.flow_hash = flow_hash_calc.get({
                    lkp.ipv4_src_addr,
                    lkp.ipv4_dst_addr,
                    lkp.ip_proto,
                    lkp.l4_src_port,
                    lkp.l4_dst_port
                });

                // 获取当前时间戳（取低 32 位）
                ig_md.current_timestamp = (bit<32>) ig_intr_md.ingress_mac_tstamp;

                // 在寄存器内完成 flowlet 检测（超时判断 + 更新时间戳）
                // 返回 1-bit 标志，避免 control 层条件复杂度超限
                bit<1> new_flowlet_flag = check_and_update_flowlet.execute(ig_md.flow_hash);
                
                // 根据标志选择转发策略（合并到单个 if-else 避免表依赖冲突）
                if (new_flowlet_flag == 1w1) {
                    // 新flowlet：分配ID，ECMP选择，保存路径
                    ig_md.flowlet_id = increment_flowlet.execute(ig_md.flow_hash);
                    flowlet_uplink.apply();
                    write_path.execute(ig_md.flow_hash);
                } else {
                    // 同一flowlet：读取保存的路径，转发
                    ig_md.selected_path = read_path.execute(ig_md.flow_hash);
                    saved_path_uplink.apply();
                }
            }
        } else if (ig_md.port_type == PORT_TYPE_UPLINK) {
            // 从Spine来的包，直接本地转发
            local_forward.apply();
        }
    }
}

#endif /* _CLOS_FORWARDING_P4_ */