# SPDX-License-Identifier: BSD-2-Clause-Views
#
# Patch QPLL1 in the shared GTHE4_COMMON for PCIe operation.
#
# Quad 224 has one GTHE4_COMMON, instantiated by the Ethernet GT wizard
# (eth_xcvr_gth_full, LOCATE_COMMON CORE).  QPLL0 runs the SFP channels at
# 10.3125 Gb/s; QPLL1 is handed to pcie4_uscale_plus, which is built with
# CONFIG.gtcom_in_core 0 and therefore has no COMMON of its own.
#
# Neither IP's parameter surface can express this.  The PCIe core cannot set
# attributes on a primitive it no longer instantiates, and the GT wizard's
# SECONDARY_QPLL_* knobs are (line rate, refclk, fracn) only -- they derive a
# single FBDIV, mirror it into FBDIV_G3, and expose nothing for PCIe mode.
# CONFIG.PCIE_ENABLE is a whole-instance switch, not per-QPLL: it would set
# PCI_EN on both QPLLs and drag QPLL0_FBDIV from 82 to 80, breaking the 10G
# link.  So the attributes are patched onto the synthesized netlist instead.
#
# QPLL1's reference clock routing is NOT set here -- it comes from
# SECONDARY_QPLL_ENABLE in ip/eth_xcvr_gth.tcl, which is what makes the wizard
# wire GTREFCLK01 to QPLL1 and set QPLL1REFCLKSEL to 3'b001.  Do not remove it.
#
# -----------------------------------------------------------------------------
# PROVENANCE OF THE VALUES BELOW
#
# Every value is what pcie4_uscale_plus programs on QPLL1 when it owns the
# COMMON itself.  Captured from Vivado 2022.2, IP xilinx.com:ip:pcie4_uscale_plus
# v1.3, on xczu5ev-sfvc784-2-i, generated with this design's configuration
# (8.0_GT/s, X2, 64_bit, Advanced, GTH_Quad_224, plltype QPLL1).
#
# To re-derive after an IP or Vivado version bump:
#
#   1. Generate pcie4_uscale_plus with the config in
#      ip/pcie4_uscale_plus_0.tcl, then generate_target {synthesis}.
#   2. Open <proj>.gen/sources_1/ip/<name>/source/<name>_gt_gt_common.v.
#   3. That file contains BOTH a GTYE4_COMMON and a GTHE4_COMMON
#      instantiation.  Take the GTHE4_COMMON one -- this is a GTH part.
#   4. Copy its .QPLL1_* attributes.
#
# QPLL1_FBDIV and QPLL1_FBDIV_G3 appear there as the localparams QPLL_FBDIV
# and QPLL_FBDIV_G34, resolved by PHY_REFCLK_FREQ.  The card edge supplies
# 100 MHz (PHY_REFCLK_FREQ == 0), which selects:
#
#     QPLL_FBDIV     = 100   Gen1/Gen2, VCO 10.0 GHz
#     QPLL_FBDIV_G3  =  80   Gen3,      VCO  8.0 GHz
#
# For reference, the other refclk choices in that table are 125 MHz -> 80/64
# and 250 MHz -> 40/32.  If the board reference ever changes, re-read them
# rather than scaling by hand.
#
# Annotations below mark which values actually differ from what the GT wizard
# emits for QPLL1 in this design, and which are already identical.  The
# identical ones are kept so the block matches its source verbatim: these
# attributes are co-tuned, and a half-and-half mix of wizard and PCIe values
# is a combination neither vendor flow validates.
# -----------------------------------------------------------------------------

set common_cells [get_cells -hierarchical -filter {REF_NAME =~ GTHE4_COMMON*}]

if {[llength $common_cells] != 1} {
    error "qpll1_pcie_attrs: expected exactly 1 GTHE4_COMMON, found [llength $common_cells]: $common_cells"
}

set common_cell [lindex $common_cells 0]

if {![string match "*eth_xcvr_gth_full*" $common_cell]} {
    error "qpll1_pcie_attrs: GTHE4_COMMON is not in the Ethernet quad wrapper: $common_cell"
}

set attrs [list]

# --- The four that decide whether the link works at all. ---------------------
# All four differ from the wizard.  Without the distinct FBDIV pair there is
# nothing for PCIERATEQPLL1 to switch between on a speed change, and the link
# cannot train below Gen3.  RATE_SW_USE_DRP selects the hardware rate-switch
# path over the DRP one; the wizard leaves it at 1'b1 in every configuration.
lappend attrs QPLL1_PCI_EN          "1'b1"                  ;# wizard: 1'b0
lappend attrs QPLL1_RATE_SW_USE_DRP "1'b0"                  ;# wizard: 1'b1
lappend attrs QPLL1_FBDIV           "100"                   ;# wizard: 80
lappend attrs QPLL1_FBDIV_G3        "80"                    ;# wizard: 80 (same)

# --- Loop dynamics: charge pump and loop filter. -----------------------------
# Xilinx annotates all four "Optimized for PCIe PLL compliance".  All four
# differ from the wizard's, which are tuned for a fixed 8.0 Gb/s link with no
# rate switching and no PCIe phase-noise mask to meet.
lappend attrs QPLL1_CP              "10'b0100010101"        ;# wizard: 0011111111
lappend attrs QPLL1_CP_G3           "10'b0100010101"        ;# wizard: 0001111111
lappend attrs QPLL1_LPF             "10'b0000010101"        ;# wizard: 1000011111
lappend attrs QPLL1_LPF_G3          "10'b0000010101"        ;# wizard: 0111010100

# --- QPLL configuration, including VCO band selection. -----------------------
# CFG2_G3 is the load-bearing one: the PCIe core's own source documents bit [6]
# as 1'b0 = upper band VCO, 1'b1 = lower band VCO, which is the mechanism for
# reaching 8.0 GHz at Gen3.  The wizard's value was computed for a secondary
# link that never rate-switches and has no reason to be right for that band.
lappend attrs QPLL1_CFG0            "16'b0011001100011100"  ;# wizard: same
lappend attrs QPLL1_CFG1            "16'b0001000000101000"  ;# wizard: 1101000000111000
lappend attrs QPLL1_CFG1_G3         "16'b0001000000101000"  ;# wizard: 1101000000111000
lappend attrs QPLL1_CFG2            "16'b0000111111000011"  ;# wizard: 0000111111000000
lappend attrs QPLL1_CFG2_G3         "16'b0000000100100000"  ;# wizard: 0000111111000000
lappend attrs QPLL1_CFG3            "16'b0000000100100000"  ;# wizard: same
lappend attrs QPLL1_CFG4            "16'b0000000001100011"  ;# wizard: 0000000000000011

# --- Sigma-delta modulator.  QPLL1 runs integer-N here. ----------------------
# The wizard's SDM_CFG0 comes from its own fractional-N bookkeeping, which
# applies to QPLL0 (the 10G link, N = 82.5), not to this PLL.
lappend attrs QPLL1_SDM_CFG0        "16'b0000000011000000"  ;# wizard: 0000000010000000
lappend attrs QPLL1_SDM_CFG1        "16'b0000000000000000"  ;# wizard: same
lappend attrs QPLL1_SDM_CFG2        "16'b0000000000000000"  ;# wizard: same

# --- Lock detector, init and reference divider. ------------------------------
# All identical to the wizard's output; kept so this block matches its source.
lappend attrs QPLL1_LOCK_CFG        "16'b0010010111101000"  ;# wizard: same
lappend attrs QPLL1_LOCK_CFG_G3     "16'b0010010111101000"  ;# wizard: same
lappend attrs QPLL1_INIT_CFG0       "16'h02B2"              ;# wizard: same
lappend attrs QPLL1_INIT_CFG1       "8'b00000000"           ;# wizard: same
lappend attrs QPLL1_REFCLK_DIV      "1"                     ;# wizard: same

puts "qpll1_pcie_attrs: patching QPLL1 on $common_cell"

set_property -dict $attrs $common_cell

puts "qpll1_pcie_attrs: QPLL1_FBDIV=[get_property QPLL1_FBDIV $common_cell] QPLL1_FBDIV_G3=[get_property QPLL1_FBDIV_G3 $common_cell] QPLL1_PCI_EN=[get_property QPLL1_PCI_EN $common_cell] QPLL1_RATE_SW_USE_DRP=[get_property QPLL1_RATE_SW_USE_DRP $common_cell]"
