#!/usr/bin/env python

import os


def list_programs():
    programs = []
    for name in dir(bfrt):
        if name.startswith("_"):
            continue
        obj = getattr(bfrt, name)
        if hasattr(obj, "pipe"):
            programs.append(name)
    return sorted(set(programs))


def pick_program(programs, preferred):
    default_programs = ["dpc_sched", "tna_simple_switch", "tna_switch"]
    if preferred and preferred in programs:
        return preferred
    for name in default_programs:
        if name in programs:
            return name
    if len(programs) == 1:
        return programs[0]
    return None


def get_ingress(pipe):
    if not hasattr(pipe, "SwitchIngress"):
        raise RuntimeError("SwitchIngress not found in BFRT program")
    si = pipe.SwitchIngress
    if hasattr(si, "dpc_sched"):
        return si.dpc_sched
    return si


def dump_table(table, name):
    try:
        print("\n== %s ==" % name)
        table.dump(table=True)
    except Exception as exc:
        print("!! Failed to dump %s: %s" % (name, exc))


programs = list_programs()
print("Available BFRT programs: %s" % (", ".join(programs) if programs else "(none)"))

preferred = os.environ.get("P4_PROGRAM")
program = pick_program(programs, preferred)

if not program:
    print("ERROR: Unable to choose a program. Set P4_PROGRAM to one of: %s" %
          (", ".join(programs) if programs else "(none)"))
    raise SystemExit(1)

if preferred and preferred != program:
    print("P4_PROGRAM='%s' not found; using '%s' instead." % (preferred, program))

print("Using program: %s" % program)

pipe = getattr(bfrt, program).pipe
ingress = get_ingress(pipe)

# ARP table lives under arp_control in this pipeline
try:
    dump_table(ingress.arp_control.arp_reply_table, "arp_control.arp_reply_table")
except Exception as exc:
    print("ARP table not found: %s" % exc)

for name in [
        "uplink_port_ip_to_nhop",
        "downlink_to_uplink_port",
        "downlink_to_uplink_port_resubmit",
        "msb_comm_table",
        "msb_comp_table",
        "cmp_exp_table",
]:
    if hasattr(ingress, name):
        dump_table(getattr(ingress, name), name)
    else:
        print("Table %s not found in program '%s'" % (name, program))
