# SPDX-License-Identifier: BSD-2-Clause-Views
#
# Register the QPLL1 PCIe attribute patch as a pre-opt_design hook, so it runs
# against the synthesized netlist before implementation.  See
# qpll1_pcie_attrs.tcl for why this cannot be done from the IP configuration.

set_property STEPS.OPT_DESIGN.TCL.PRE \
    [file join [file normalize [file dirname [info script]]] qpll1_pcie_attrs.tcl] \
    [get_runs impl_1]
