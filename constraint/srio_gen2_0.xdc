#-----------------------------------------------------------------------------
#
# File name:    srio_gen2_0.xdc
# Rev:          4.0
# Description:  This module constrains the example design
#
#-----------------------------------------------------------------------------
######################################
#         Core Time Specs            #
######################################

create_clock -period 6.4 -name sys_clkp [get_ports sys_clkp]
set_case_analysis 0 [list [get_pins -hierarchical *mode_1x]]
set_false_path -to [get_cells -hierarchical -filter {name =~ *gt_decode_error_phy_clk_stg1_reg}]

set_false_path -to [get_cells -hierarchical -filter {NAME =~ *data_sync_reg1}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *ack_sync_reg1}]
#set_multicycle_path -from [get_pins *cfg_raddr_reg* -hierarchical] -to [get_pins *cfg_reg*rdata_reg* -hierarchical] 3
#set_multicycle_path -from [get_pins *cfg_raddr_reg* -hierarchical] -to [get_pins *cfg_reg*rdata_reg* -hierarchical] 2 -hold

######################################################
##       GT and Pin Locations                        #
## NOTE: These pins were selected for:               #
## XC7KX325T FFG900                                  #
## Pins for any other part/package must be relocated #
######################################################

#set_property LOC GTXE2_CHANNEL_X0Y8 [get_cells -hier -nocase -regexp {.*/gt0_srio_gen2_0_i/gt.e2_i}] 
#set_property LOC GTXE2_CHANNEL_X0Y8 [get_cells -hier -nocase -regexp {.*/gt0_srio_gen2_0_i/gt.e2_i}]


set_property LOC C8  [get_ports sys_clkp]
set_property LOC C7  [get_ports sys_clkn]
set_property LOC R24 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS25 [get_ports sys_rst_n]

## SI53301
set_property PACKAGE_PIN A16 [get_ports si53301_OEA]
set_property IOSTANDARD LVCMOS15 [get_ports si53301_OEA]

set_property PACKAGE_PIN A17 [get_ports si53301_OEB]
set_property IOSTANDARD LVCMOS15 [get_ports si53301_OEB]

set_property PACKAGE_PIN C20 [get_ports si53301_CLKSEL]
set_property IOSTANDARD LVCMOS15 [get_ports si53301_CLKSEL]

## FSP
set_property PACKAGE_PIN AJ27 [get_ports fsp_disable[0]]
set_property IOSTANDARD LVCMOS33 [get_ports fsp_disable[0]]

set_property PACKAGE_PIN AJ28 [get_ports fsp_disable[1]]
set_property IOSTANDARD LVCMOS33 [get_ports fsp_disable[1]]

set_property PACKAGE_PIN AD29 [get_ports fsp_disable[2]]
set_property IOSTANDARD LVCMOS33 [get_ports fsp_disable[2]]

set_property PACKAGE_PIN W27 [get_ports fsp_disable[3]]
set_property IOSTANDARD LVCMOS33 [get_ports fsp_disable[3]]


# DP1 MGT0_118
set_property PACKAGE_PIN D1 [get_ports srio_txn0]
set_property PACKAGE_PIN E3 [get_ports srio_rxn0]
set_property PACKAGE_PIN E4 [get_ports srio_rxp0]
set_property PACKAGE_PIN D2 [get_ports srio_txp0]

#LED_GREEN D4 core-board 
set_property PACKAGE_PIN P19 [get_ports led0[0]]
set_property IOSTANDARD LVCMOS25 [get_ports led0[0]]
#LED_yellow D3 core-board
set_property PACKAGE_PIN W19 [get_ports led0[1]]
set_property IOSTANDARD LVCMOS25 [get_ports led0[1]]

#set_property LOC A20 [get_ports led0[7]]
#set_property LOC A17 [get_ports led0[6]]
#set_property LOC A16 [get_ports led0[5]]
#set_property LOC B20 [get_ports led0[4]]
#set_property LOC C20 [get_ports led0[3]]
#set_property LOC F17 [get_ports led0[2]]
#set_property LOC G17 [get_ports led0[1]]
#set_property LOC B17 [get_ports led0[0]]

#set_property LOC C19 [get_ports sim_train_en]

##set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n]
#set_property IOSTANDARD LVCMOS18 [get_ports sim_train_en]

#set_property IOSTANDARD LVCMOS18 [get_ports led0[7]]
#set_property IOSTANDARD LVCMOS18 [get_ports led0[6]]
#set_property IOSTANDARD LVCMOS18 [get_ports led0[5]]
#set_property IOSTANDARD LVCMOS18 [get_ports led0[4]]
#set_property IOSTANDARD LVCMOS18 [get_ports led0[3]]
#set_property IOSTANDARD LVCMOS18 [get_ports led0[2]]
#set_property IOSTANDARD LVCMOS18 [get_ports led0[1]]
#set_property IOSTANDARD LVCMOS18 [get_ports led0[0]]

# set_property PULLUP TRUE [get_ports sys_rst]


