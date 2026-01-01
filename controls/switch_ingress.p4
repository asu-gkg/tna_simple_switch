#ifndef _SWITCH_INGRESS_P4_
#define _SWITCH_INGRESS_P4_

control SwitchIngress(
        inout header_t hdr,
        inout ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    PortMapping(1024, 1024) port_mapping;
    PktValidation() pkt_validation;
    MAC(1024) mac;
    FIB(1024, 1024) fib;
    Nexthop(1024) nexthop;
    LAG() lag;
    ClosForwarding() clos;

    lookup_fields_t lkp;

    action do_arp_reply(mac_addr_t my_mac) {
        mac_addr_t temp_mac = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = my_mac;

        hdr.arp.oper = ARP_REPLY;
        mac_addr_t temp_sha = hdr.arp.sha;
        ipv4_addr_t temp_spa = hdr.arp.spa;

        hdr.arp.sha = my_mac;
        hdr.arp.spa = hdr.arp.tpa;
        hdr.arp.tha = temp_sha;
        hdr.arp.tpa = temp_spa;
    }

    table arp_reply_table {
        key = {
            hdr.arp.tpa : exact;
        }
        actions = {
            do_arp_reply;
            NoAction;
        }
        const default_action = NoAction;
        size = 32;
    }

    action rmac_hit() { }
    table rmac {
        key = {
            lkp.mac_dst_addr : exact;
        }

        actions = {
            NoAction;
            rmac_hit;
        }

        const default_action = NoAction;
        size = 1024;
    }

    apply {
        if (hdr.arp.isValid() && hdr.arp.oper == ARP_REQUEST) {
            if (arp_reply_table.apply().hit) {
                ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
                return;
            }
        }

        pkt_validation.apply(hdr, lkp);

        clos.apply(lkp, hdr, ig_md, ig_intr_md.ingress_port, ig_tm_md.ucast_egress_port, ig_dprsr_md);

        if (ig_md.port_type != PORT_TYPE_UNKNOWN) {
            return;
        }

        port_mapping.apply(ig_intr_md.ingress_port, ig_md);
        switch (rmac.apply().action_run) {
            rmac_hit : {
                if (!BYPASS(L3)) {
                    if (lkp.ip_version == 4w4) {
                        fib.apply(lkp.ipv4_dst_addr, ig_md.vrf, ig_md.nexthop);
                    }
                }
            }
        }

        nexthop.apply(lkp, hdr, ig_md);
        if (!BYPASS(L2)) {
            mac.apply(hdr.ethernet.dst_addr, ig_md.bd, ig_md.egress_ifindex);
        }

        lag.apply(lkp, ig_md.egress_ifindex, ig_tm_md.ucast_egress_port);
    }
}

#endif /* _SWITCH_INGRESS_P4_ */

