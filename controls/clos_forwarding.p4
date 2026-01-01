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
    Register<bit<48>, flow_hash_t>(32768) flowlet_last_seen;  // 上次包时间戳
    Register<flowlet_id_t, flow_hash_t>(32768) flowlet_counter; // flowlet计数器
    Register<path_id_t, flow_hash_t>(32768) flowlet_path;    // 当前路径

    // 更新时间戳并返回上次时间戳
    RegisterAction<bit<48>, flow_hash_t, bit<48>>(flowlet_last_seen) update_timestamp = {
        void apply(inout bit<48> value, out bit<48> result) {
            result = value;
            value = ig_md.current_timestamp;
        }
    };

    // 递增flowlet计数器
    RegisterAction<flowlet_id_t, flow_hash_t, flowlet_id_t>(flowlet_counter) increment_flowlet = {
        void apply(inout flowlet_id_t value, out flowlet_id_t result) {
            value = value + 1;
            result = value;
        }
    };

    // 获取或设置路径
    RegisterAction<path_id_t, flow_hash_t, path_id_t>(flowlet_path) get_set_path = {
        void apply(inout path_id_t value, out path_id_t result) {
            if (ig_md.is_new_flowlet) {
                value = ig_md.selected_path;
            }
            result = value;
        }
    };

    // Flowlet检测动作
    action detect_flowlet() {
        // 计算flow hash (基于5-tuple)
        ig_md.flow_hash = flow_hash_calc.get({
            lkp.ipv4_src_addr,
            lkp.ipv4_dst_addr,
            lkp.ip_proto,
            lkp.l4_src_port,
            lkp.l4_dst_port
        });

        // 获取当前时间戳
        ig_md.current_timestamp = ig_intr_md.ingress_mac_tstamp;

        // 获取上次包的时间戳并更新
        ig_md.last_seen_timestamp = update_timestamp.execute(ig_md.flow_hash);

        // 计算包间隔
        ig_md.flowlet_gap = ig_md.current_timestamp - ig_md.last_seen_timestamp;

        // 判断是否新flowlet
        if (ig_md.flowlet_gap > FLOWLET_TIMEOUT || ig_md.last_seen_timestamp == 0) {
            ig_md.is_new_flowlet = true;
            // 为新flowlet分配ID
            ig_md.flowlet_id = increment_flowlet.execute(ig_md.flow_hash);
        } else {
            ig_md.is_new_flowlet = false;
        }
    }

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
    action forward_saved_path(PortId_t port1, mac_addr_t spine_mac1, mac_addr_t edge_mac1,
                             PortId_t port2, mac_addr_t spine_mac2, mac_addr_t edge_mac2) {
        // 根据保存的路径ID选择对应的端口
        if (ig_md.selected_path == (path_id_t)(port1 & 0xFF)) {
            egress_port = port1;
            hdr.ethernet.dst_addr = spine_mac1;
            hdr.ethernet.src_addr = edge_mac1;
        } else {
            egress_port = port2;
            hdr.ethernet.dst_addr = spine_mac2;
            hdr.ethernet.src_addr = edge_mac2;
        }
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    // 已保存路径的转发表
    table saved_path_uplink {
        key = {
            ig_md.src_edge : exact;
        }
        actions = {
            forward_saved_path;
            ecmp_miss;
        }
        const default_action = ecmp_miss;
        size = 16;
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

                // Step 1: 执行flowlet检测
                detect_flowlet();

                // Step 2: 根据是否新flowlet选择转发策略
                if (ig_md.is_new_flowlet) {
                    // 新flowlet：重新进行ECMP选择
                    if (flowlet_uplink.apply().hit) {
                        // 保存新选择的路径
                        ig_md.selected_path = get_set_path.execute(ig_md.flow_hash);
                    }
                } else {
                    // 同一flowlet：使用之前保存的路径
                    ig_md.selected_path = get_set_path.execute(ig_md.flow_hash);

                    // 根据保存的路径进行转发
                    if (!saved_path_uplink.apply().hit) {
                        // 如果保存的路径表没有匹配，退回到flowlet ECMP
                        flowlet_uplink.apply();
                    }
                }
            }
        } else if (ig_md.port_type == PORT_TYPE_UPLINK) {
            // 从Spine来的包，直接本地转发
            local_forward.apply();
        }
    }
}

#endif /* _CLOS_FORWARDING_P4_ */