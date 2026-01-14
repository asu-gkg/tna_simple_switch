control ARPControl(inout header_t hdr, 
    in ingress_intrinsic_metadata_t ig_intr_md, 
    inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

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

    apply {
        arp_reply_table.apply();
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
    }
}