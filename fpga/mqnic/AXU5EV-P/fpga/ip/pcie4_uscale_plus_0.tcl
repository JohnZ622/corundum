
create_ip -name pcie4_uscale_plus -vendor xilinx.com -library ip -module_name pcie4_uscale_plus_0

# Class code 020000 is Ethernet controller
# device ID will be overriden

# --- Why we put PCIE4 on QPLL1 and not QPLL0 ---
# Gen3 needs an 8.0 GHz VCO, which is inside QPLL1's
# 8.0-13.0 GHz range but below QPLL0's 9.8 GHz floor.  QPLL0 belongs to the
# 10.3125 Gb/s Ethernet link, which fits either PLL.  QPLL1 is also this IP's
# own default at Gen3; pinning it keeps fpga/qpll1_pcie_attrs.tcl patching the
# right PLL, since that patch names QPLL1_* explicitly and would otherwise
# silently succeed while configuring the wrong one.  Full rationale in
# ip/eth_xcvr_gth.tcl.
set_property -dict [list \
    CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {8.0_GT/s} \
    CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X2} \
    CONFIG.AXISTEN_IF_RC_STRADDLE {false} \
    CONFIG.axisten_if_enable_client_tag {true} \
    CONFIG.axisten_if_width {64_bit} \
    CONFIG.extended_tag_field {true} \
    CONFIG.pf0_dev_cap_max_payload {1024_bytes} \
    CONFIG.axisten_freq {250} \
    CONFIG.PF0_Use_Class_Code_Lookup_Assistant {false} \
    CONFIG.PF0_CLASS_CODE {020000} \
    CONFIG.PF0_DEVICE_ID {9032} \
    CONFIG.PF0_SUBSYSTEM_ID {0007} \
    CONFIG.PF0_SUBSYSTEM_VENDOR_ID {10ee} \
    CONFIG.pf0_bar0_64bit {true} \
    CONFIG.pf0_bar0_prefetchable {true} \
    CONFIG.pf0_bar0_scale {Megabytes} \
    CONFIG.pf0_bar0_size {16} \
    CONFIG.pf0_msi_enabled {false} \
    CONFIG.pf0_msix_enabled {true} \
    CONFIG.PF0_MSIX_CAP_TABLE_SIZE {01F} \
    CONFIG.PF0_MSIX_CAP_TABLE_BIR {BAR_1:0} \
    CONFIG.PF0_MSIX_CAP_TABLE_OFFSET {00010000} \
    CONFIG.PF0_MSIX_CAP_PBA_BIR {BAR_1:0} \
    CONFIG.PF0_MSIX_CAP_PBA_OFFSET {00018000} \
    CONFIG.MSI_X_OPTIONS {MSI-X_External} \
    CONFIG.vendor_id {10ee} \
    CONFIG.mode_selection {Advanced} \
    CONFIG.plltype {QPLL1} \
    CONFIG.gtcom_in_core {0} \
    CONFIG.disable_gt_loc {true} \
] [get_ips pcie4_uscale_plus_0]
