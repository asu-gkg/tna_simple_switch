#include <core.p4>
#include <tna.p4>

#include "headers.p4"
#include "metadata.p4"

#include "parsers/ingress_parser.p4"
#include "parsers/egress_parser.p4"

#include "controls/ingress.p4"
#include "controls/egress.p4"

#include "deparsers/ingress_deparser.p4"
#include "deparsers/egress_deparser.p4"

Pipeline(
    SwitchIngressParser(),
    SwitchIngress(),
    SwitchIngressDeparser(),
    SwitchEgressParser(),
    SwitchEgress(),
    SwitchEgressDeparser()
) pipe;

Switch(pipe) main;


