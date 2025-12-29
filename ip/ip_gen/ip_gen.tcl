create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {50.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.USE_RESET {false} \
  CONFIG.CLKIN1_JITTER_PS {200.0} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {20.000} \
  CONFIG.MMCM_CLKIN1_PERIOD {20.000} \
  CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {5.000} \
  CONFIG.CLKOUT1_JITTER {142.107} \
  CONFIG.CLKOUT1_PHASE_ERROR {164.985} \
  ] [get_ips clk_wiz_0]

