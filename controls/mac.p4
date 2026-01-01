#ifndef _MAC_P4_
#define _MAC_P4_

control MAC(
        in mac_addr_t dst_addr,
        in bd_t bd,
        out ifindex_t egress_ifindex)(
        bit<32> mac_table_size) {

    action dmac_miss() {
        egress_ifindex = 16w0xffff;
    }

    action dmac_hit(ifindex_t ifindex) {
        egress_ifindex = ifindex;
    }

    table dmac {
        key = {
            bd : exact;
            dst_addr : exact;
        }

        actions = {
            dmac_miss;
            dmac_hit;
        }

        const default_action = dmac_miss;
        size = mac_table_size;
    }

    apply {
        dmac.apply();
    }
}

#endif /* _MAC_P4_ */

