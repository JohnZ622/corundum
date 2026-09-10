# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2022-2023 The Regents of the University of California

set base_name {eth_xcvr_gth}

set preset {GTH-10GBASE-R}

set freerun_freq {125}
set line_rate {10.3125}
# Board oscillator G1 is 125.000 MHz.  10.3125 Gb/s needs QPLL N = 82.5, which
# is reachable only via fractional-N -- see the fracn arithmetic below.
set refclk_freq {125}
# Secondary QPLL (QPLL1) is not for Ethernet: it is handed to the PCIe hard
# block, which runs Gen3 (8.0 Gb/s) off the 100 MHz refclk from the card edge.
# With CONFIG.gtcom_in_core 0 the PCIe core has no DRP path to this COMMON, so
# QPLL1 must be configured here at build time.
#
# WHY THIS WAY ROUND (Ethernet on QPLL0, PCIe on QPLL1) -- it is not arbitrary.
# The two QPLLs have different VCO ranges on UltraScale+ GTH:
#     QPLL0  9.8 - 16.375 GHz
#     QPLL1  8.0 - 13.0   GHz
# Ethernet is indifferent: 10.3125 Gb/s wants a 10.3125 GHz VCO, comfortably
# inside both.  PCIe is not.  Gen3 wants an 8.0 GHz VCO, which is inside QPLL1's
# native range but BELOW QPLL0's 9.8 GHz floor, so on QPLL0 it can only be
# reached through the lower-band VCO path (QPLL_CFG2_G3 bit [6]).
#
# The wizard CANNOT fully configure QPLL1 for PCIe -- it derives one FBDIV and
# mirrors it into FBDIV_G3 (80/80), leaves QPLL1_PCI_EN at 1'b0 and
# QPLL1_RATE_SW_USE_DRP at 1'b1, and exposes no PCIe knobs for a secondary
# QPLL.  (CONFIG.PCIE_ENABLE does not help: it applies PCIe mode to the PRIMARY
# QPLL, clobbering QPLL0_FBDIV from 82 to 80 and breaking the 10G link.)
# Those attributes are patched onto the netlist instead -- see
# fpga/qpll1_pcie_attrs.tcl.  What this setting IS load-bearing for is the
# reference clock: it makes the wizard wire GTREFCLK01 to QPLL1 and set
# QPLL1REFCLKSEL to 3'b001, which the netlist patch does not do.
set sec_line_rate {8.0}
set sec_refclk_freq {100}
# QPLL fractional-N.  The wizard's convention is N = N_int + FRACN/2**24 where
# N = VCO/refclk and the VCO runs at the line rate, i.e. N = line_rate*1000/refclk.
# Upstream Corundum divides by 2 here, which yields half the correct numerator;
# that bug is invisible on every upstream board because they all use integer-N
# refclks (156.25 -> 0 either way).  It is NOT invisible at 125 MHz: N = 82.5
# needs 0.5*2**24 = 8388608, not the 4194304 the upstream expression produces.
# Verified against gtwizard_ultrascale on xczu5ev-sfvc784-2-i, Vivado 2022.2:
# refclk 125 is accepted with 8388608 and rejected with 0/2097152/4194304/
# 12582912/16777215.  The wizard validates refclk and numerator as a pair.
set qpll_fracn [expr {int(fmod($line_rate*1000 / $refclk_freq, 1)*pow(2, 24))}]
set sec_qpll_fracn [expr {int(fmod($sec_line_rate*1000 / $sec_refclk_freq, 1)*pow(2, 24))}]
set user_data_width {64}
set int_data_width {32}
set rx_eq_mode {DFE}
set extra_ports [list]
set extra_pll_ports [list]
# DRP connections
lappend extra_ports drpclk_in drpaddr_in drpdi_in drpen_in drpwe_in drpdo_out drprdy_out
lappend extra_pll_ports drpclk_common_in drpaddr_common_in drpdi_common_in drpen_common_in drpwe_common_in drpdo_common_out drprdy_common_out
# PLL reset and power down
lappend extra_pll_ports qpll0reset_in qpll1reset_in
lappend extra_pll_ports qpll0pd_in qpll1pd_in
# PLL clocking
lappend extra_pll_ports gtrefclk00_in qpll0lock_out qpll0outclk_out qpll0outrefclk_out
lappend extra_pll_ports gtrefclk01_in qpll1lock_out qpll1outclk_out qpll1outrefclk_out
# PCIe
if {[string first uplus [get_property FAMILY [get_property PART [current_project]]]] != -1} {
    lappend extra_pll_ports pcierateqpll0_in pcierateqpll1_in
} else {
    lappend extra_pll_ports qpllrsvd2_in qpllrsvd3_in
}
# channel reset
lappend extra_ports gttxreset_in txuserrdy_in txpmareset_in txpcsreset_in txresetdone_out txpmaresetdone_out
lappend extra_ports gtrxreset_in rxuserrdy_in rxpmareset_in rxdfelpmreset_in eyescanreset_in rxpcsreset_in rxresetdone_out rxpmaresetdone_out
# channel power down
lappend extra_ports txpd_in txpdelecidlemode_in rxpd_in
# channel clock selection
lappend extra_ports txsysclksel_in txpllclksel_in rxsysclksel_in rxpllclksel_in
# channel polarity
lappend extra_ports txpolarity_in rxpolarity_in
# channel TX driver
lappend extra_ports txelecidle_in txinhibit_in txdiffctrl_in txmaincursor_in txprecursor_in txpostcursor_in
# channel CDR
lappend extra_ports rxcdrlock_out rxcdrhold_in
# channel EQ
lappend extra_ports rxlpmen_in
# channel digital monitor
lappend extra_ports dmonitorout_out
# channel PRBS
lappend extra_ports txprbsforceerr_in txprbssel_in rxprbscntreset_in rxprbssel_in rxprbserr_out rxprbslocked_out
# channel eye scan
lappend extra_ports eyescandataerror_out
# channel loopback
lappend extra_ports loopback_in

set config [dict create]

dict set config TX_LINE_RATE $line_rate
dict set config TX_REFCLK_FREQUENCY $refclk_freq
dict set config TX_QPLL_FRACN_NUMERATOR $qpll_fracn
dict set config TX_USER_DATA_WIDTH $user_data_width
dict set config TX_INT_DATA_WIDTH $int_data_width
dict set config RX_LINE_RATE $line_rate
dict set config RX_REFCLK_FREQUENCY $refclk_freq
dict set config RX_QPLL_FRACN_NUMERATOR $qpll_fracn
dict set config RX_USER_DATA_WIDTH $user_data_width
dict set config RX_INT_DATA_WIDTH $int_data_width
dict set config RX_EQ_MODE $rx_eq_mode
if {$sec_line_rate != 0} {
    dict set config SECONDARY_QPLL_ENABLE true
    dict set config SECONDARY_QPLL_FRACN_NUMERATOR $sec_qpll_fracn
    dict set config SECONDARY_QPLL_LINE_RATE $sec_line_rate
    dict set config SECONDARY_QPLL_REFCLK_FREQUENCY $sec_refclk_freq
} else {
    dict set config SECONDARY_QPLL_ENABLE false
}
dict set config ENABLE_OPTIONAL_PORTS $extra_ports
dict set config LOCATE_COMMON {CORE}
dict set config LOCATE_RESET_CONTROLLER {EXAMPLE_DESIGN}
dict set config LOCATE_TX_USER_CLOCKING {CORE}
dict set config LOCATE_RX_USER_CLOCKING {CORE}
dict set config LOCATE_USER_DATA_WIDTH_SIZING {CORE}
dict set config FREERUN_FREQUENCY $freerun_freq
dict set config DISABLE_LOC_XDC {1}

proc create_gtwizard_ip {name preset config} {
    create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name $name
    set ip [get_ips $name]
    set_property CONFIG.preset $preset $ip
    set config_list {}
    dict for {name value} $config {
        lappend config_list "CONFIG.${name}" $value
    }
    set_property -dict $config_list $ip
}

# variant with channel and common
dict set config ENABLE_OPTIONAL_PORTS [concat $extra_pll_ports $extra_ports]
dict set config LOCATE_COMMON {CORE}

create_gtwizard_ip "${base_name}_full" $preset $config

# variant with channel only
dict set config ENABLE_OPTIONAL_PORTS $extra_ports
dict set config LOCATE_COMMON {EXAMPLE_DESIGN}

create_gtwizard_ip "${base_name}_channel" $preset $config
