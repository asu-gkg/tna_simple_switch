#ifndef _FIB_P4_
#define _FIB_P4_

control FIB(
        in ipv4_addr_t dst_addr,
        in vrf_t vrf,
        out nexthop_t nexthop)(
        bit<32> host_table_size,
        bit<32> lpm_table_size) {

    action fib_hit(nexthop_t nexthop_index) {
        nexthop = nexthop_index;
    }

    action fib_miss() {
        nexthop = 0;  // Initialize to default value
    }

    table fib {
        key = {
            vrf : exact;
            dst_addr : exact;
        }

        actions = {
            fib_miss;
            fib_hit;
        }

        const default_action = fib_miss;
        size = host_table_size;
    }

    table fib_lpm {
        key = {
            vrf : exact;
            dst_addr : lpm;
        }

        actions = {
            fib_miss;
            fib_hit;
        }

        const default_action = fib_miss;
        size = lpm_table_size;
    }

    apply {
        if (!fib.apply().hit) {
            fib_lpm.apply();
        }
    }
}

#endif /* _FIB_P4_ */

