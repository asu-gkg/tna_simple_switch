#ifndef _LAG_P4_
#define _LAG_P4_

control LAG(
        in lookup_fields_t lkp,
        in ifindex_t ifindex,
        out PortId_t egress_port) {
    Hash<bit<32>>(HashAlgorithm_t.CRC32) sel_hash;
    ActionSelector(1024, sel_hash, SelectorMode_t.FAIR) lag_selector;

    action set_port(PortId_t port) {
        egress_port = port;
    }

    action lag_miss() {
        egress_port = 0;  // Initialize to default value
    }

    table lag {
        key = {
            ifindex : exact;
            lkp.ipv4_src_addr : selector;
            lkp.ipv4_dst_addr : selector;
            lkp.ip_proto : selector;
            lkp.l4_src_port : selector;
            lkp.l4_dst_port : selector;
        }

        actions = {
            lag_miss;
            set_port;
        }

        const default_action = lag_miss;
        size = 1024;
        implementation = lag_selector;
    }

    apply {
        lag.apply();
    }
}

#endif /* _LAG_P4_ */

