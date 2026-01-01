#ifndef _PKT_VALIDATION_P4_
#define _PKT_VALIDATION_P4_

control PktValidation(
        in header_t hdr,
        out lookup_fields_t lkp) {

    const bit<32> table_size = 512;

    action malformed_pkt() {
        // drop.
    }

    action valid_pkt_untagged() {
        lkp.mac_src_addr = hdr.ethernet.src_addr;
        lkp.mac_dst_addr = hdr.ethernet.dst_addr;
        lkp.mac_type = hdr.ethernet.ether_type;
    }

    table validate_ethernet {
        key = {
            hdr.ethernet.src_addr : ternary;
            hdr.ethernet.dst_addr : ternary;
        }

        actions = {
            malformed_pkt;
            valid_pkt_untagged;
        }

        size = table_size;
    }

    action valid_ipv4_pkt() {
        lkp.ip_version = 4w4;
        lkp.ip_dscp = hdr.ipv4.diffserv;
        lkp.ip_proto = hdr.ipv4.protocol;
        lkp.ip_ttl = hdr.ipv4.ttl;
        lkp.ipv4_src_addr = hdr.ipv4.src_addr;
        lkp.ipv4_dst_addr = hdr.ipv4.dst_addr;
    }

    table validate_ipv4 {
        key = {
            hdr.ipv4.version : ternary;
            hdr.ipv4.ihl : ternary;
            hdr.ipv4.ttl : ternary;
        }

        actions = {
            valid_ipv4_pkt;
            malformed_pkt;
        }

        size = table_size;
    }

    apply {
        validate_ethernet.apply();
        if (hdr.ipv4.isValid()) {
            validate_ipv4.apply();
        }
        if (hdr.tcp.isValid()) {
            lkp.l4_src_port = hdr.tcp.src_port;
            lkp.l4_dst_port = hdr.tcp.dst_port;
        } else if (hdr.udp.isValid()) {
            lkp.l4_src_port = hdr.udp.src_port;
            lkp.l4_dst_port = hdr.udp.dst_port;
        } else {
            lkp.l4_src_port = 0;
            lkp.l4_dst_port = 0;
        }
    }
}

#endif /* _PKT_VALIDATION_P4_ */

