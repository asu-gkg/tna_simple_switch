#ifndef _PORT_MAPPING_P4_
#define _PORT_MAPPING_P4_

control PortMapping(
        in PortId_t port,
        inout ingress_metadata_t ig_md)(
        bit<32> port_table_size,
        bit<32> bd_table_size) {

    ActionProfile(bd_table_size) bd_action_profile;

    action set_port_attributes(ifindex_t ifindex) {
        ig_md.ifindex = ifindex;
    }

    table port_mapping {
        key = { port : exact; }
        actions = { set_port_attributes; }
    }

    action set_bd_attributes(bd_t bd, vrf_t vrf) {
        ig_md.bd = bd;
        ig_md.vrf = vrf;
    }

    table port_to_bd_mapping {
        key = {
            ig_md.ifindex : exact;
        }

        actions = {
            NoAction;
            set_bd_attributes;
        }

        const default_action = NoAction;
        implementation = bd_action_profile;
        size = port_table_size;
    }

    apply {
        port_mapping.apply();
        port_to_bd_mapping.apply();
    }
}

#endif /* _PORT_MAPPING_P4_ */

