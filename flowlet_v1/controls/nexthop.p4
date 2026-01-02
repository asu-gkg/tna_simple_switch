#ifndef _NEXTHOP_P4_
#define _NEXTHOP_P4_

control Nexthop(
        in lookup_fields_t lkp,
        inout header_t hdr,
        inout ingress_metadata_t ig_md)(
        bit<32> table_size) {
    bool routed;
    Hash<bit<32>>(HashAlgorithm_t.CRC32) sel_hash;
    ActionSelector(
        1024, sel_hash, SelectorMode_t.FAIR) ecmp_selector;

    action set_nexthop_attributes(bd_t bd, mac_addr_t dmac) {
        routed = true;
        ig_md.bd = bd;
        hdr.ethernet.dst_addr = dmac;
    }

    table ecmp {
        key = {
            ig_md.nexthop : exact;
            lkp.ipv4_src_addr : selector;
            lkp.ipv4_dst_addr : selector;
            lkp.ip_proto : selector;
            lkp.l4_src_port : selector;
            lkp.l4_dst_port : selector;
        }

        actions = {
            NoAction;
            set_nexthop_attributes;
        }

        const default_action = NoAction;
        size = table_size;
        implementation = ecmp_selector;
    }

    table nexthop {
        key = {
            ig_md.nexthop : exact;
        }

        actions = {
            NoAction;
            set_nexthop_attributes;
        }

        const default_action = NoAction;
        size = table_size;
    }

    action rewrite_ipv4() {
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ip_rewrite {
        key = {
            hdr.ipv4.isValid() : exact;
        }

        actions = {
            rewrite_ipv4;
        }

        const entries = {
            true : rewrite_ipv4();
        }
    }

    action rewrite_smac(mac_addr_t smac) {
        hdr.ethernet.src_addr = smac;
    }

    table smac_rewrite {
        key = { ig_md.bd : exact; }
        actions = {
            NoAction;
            rewrite_smac;
        }

        const default_action = NoAction;
    }

    apply {
        routed = false;
        switch(nexthop.apply().action_run) {
            NoAction : { ecmp.apply(); }
        }

        if (routed) {
            ip_rewrite.apply();
            smac_rewrite.apply();
        }
    }
}

#endif /* _NEXTHOP_P4_ */

