#include <tna.p4>
#include <core.p4>

#include "headers.p4"
#include "metadata.p4"

#include "switch_ingress_parser.p4"
#include "switch_ingress.p4"
#include "switch_ingress_deparser.p4"
#include "switch_egress_parser.p4"
#include "switch_egress.p4"
#include "switch_egress_deparser.p4"


Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         SwitchEgressParser(),
         SwitchEgress(),
         SwitchEgressDeparser()) pipe;

Switch(pipe) main;