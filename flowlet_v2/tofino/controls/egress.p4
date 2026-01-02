#ifndef _FLOWLET_TNA_EGRESS_P4_
#define _FLOWLET_TNA_EGRESS_P4_

control SwitchEgress(
        inout header_t hdr,
        inout egress_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport) {
    apply {
        // All forwarding decisions are done in ingress in this minimal program.
    }
}

#endif /* _FLOWLET_TNA_EGRESS_P4_ */


