#ifndef _SWITCH_INGRESS_DEPARSER_P4_
#define _SWITCH_INGRESS_DEPARSER_P4_

control SwitchIngressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.arp);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.tcp);
        pkt.emit(hdr.udp);
    }
}

#endif /* _SWITCH_INGRESS_DEPARSER_P4_ */

