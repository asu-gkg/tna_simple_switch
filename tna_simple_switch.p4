#include <core.p4>
#include <tna.p4>
#include "headers.p4"
#include "metadata.p4"
#include "controls/pkt_validation.p4"
#include "controls/port_mapping.p4"
#include "controls/mac.p4"
#include "controls/fib.p4"
#include "controls/nexthop.p4"
#include "controls/lag.p4"
#include "controls/clos_forwarding.p4"
#include "controls/switch_ingress.p4"
#include "controls/switch_egress.p4"
#include "parsers/switch_ingress_parser.p4"
#include "parsers/switch_egress_parser.p4"
#include "deparsers/switch_ingress_deparser.p4"
#include "deparsers/switch_egress_deparser.p4"

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         SwitchEgressParser(),
         SwitchEgress(),
         SwitchEgressDeparser()) pipe;

Switch(pipe) main;

