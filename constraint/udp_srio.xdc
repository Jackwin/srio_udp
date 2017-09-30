
#------------------------ SRIO BEGIN--------------------------------------

create_clock -period 8.0 -name sys_clk [get_ports srio_refclkp]
set_case_analysis 0 [list [get_pins -hierarchical *mode_1x]]
set_false_path -to [get_cells -hierarchical -filter {name =~ *gt_decode_error_phy_clk_stg1_reg}]

set_false_path -to [get_cells -hierarchical -filter {NAME =~ *data_sync_reg1}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *ack_sync_reg1}]

## Reference clock
set_property LOC A10  [get_ports srio_refclkp]
set_property LOC A9  [get_ports srio_refclkn]

# MGT119
set_property PACKAGE_PIN E2 [get_ports srio_txp0]
set_property PACKAGE_PIN E1 [get_ports srio_txn0]
set_property PACKAGE_PIN D8 [get_ports srio_rxp0]
set_property PACKAGE_PIN D7 [get_ports srio_rxn0]

set_property PACKAGE_PIN D4 [get_ports srio_txp1]
set_property PACKAGE_PIN D3 [get_ports srio_txn1]
set_property PACKAGE_PIN C6 [get_ports srio_rxp1]
set_property PACKAGE_PIN C5 [get_ports srio_rxn1]

set_property PACKAGE_PIN C2 [get_ports srio_txp2]
set_property PACKAGE_PIN C1 [get_ports srio_txn2]
set_property PACKAGE_PIN B8 [get_ports srio_rxp2]
set_property PACKAGE_PIN B7 [get_ports srio_rxn2]

set_property PACKAGE_PIN B4 [get_ports srio_txp3]
set_property PACKAGE_PIN B3 [get_ports srio_txn3]
set_property PACKAGE_PIN A6 [get_ports srio_rxp3]
set_property PACKAGE_PIN A5 [get_ports srio_rxn3]

##GPIO_LED0

set_property PACKAGE_PIN AM39 [get_ports {srio_led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {srio_led[0]}]
##GPIO_LED1
set_property PACKAGE_PIN AN39 [get_ports {srio_led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {srio_led[1]}]





#------------------------ SRIO END --------------------------------------

#------------------------ Ethernet BEGIN---------------------------------
## 200M input clock
set_property PACKAGE_PIN E18 [get_ports clk_in_n]
set_property IOSTANDARD LVDS [get_ports clk_in_p]
set_property IOSTANDARD LVDS [get_ports clk_in_n]
create_clock -period 5.000 -name clk_in_p [get_ports clk_in_p]
create_clock -period 5.000 [get_ports clk_in_n]


#125M input clock
set_property PACKAGE_PIN AH7 [get_ports gtrefclk_n]
create_clock -period 8.000 -name gtrefclk [get_pins "*/core_support_i/core_clocking_i/ibufds_gtrefclk/O"]

#create_generated_clock -name clkudp_31_25M -source [get_ports gtrefclk_n] [get_pins "*/core_support_i/core_clocking_i/mmcm_adv_inst/CLKOUT2"]
#create_generated_clock -name clk_62_5M -source [get_ports gtrefclk_n] [get_pins "*/core_support_i/core_clocking_i/mmcm_adv_inst/CLKOUT1"]
#create_generated_clock -name clk_125M -source [get_ports gtrefclk_n] [get_pins "*/core_support_i/core_clocking_i/mmcm_adv_inst/CLKOUT0"]

#set_false_path -from [get_clocks -include_generated_clocks clkudp_31_25M] -to [get_clocks -include_generated_clocks clk_125M]
#set_false_path -from [get_clocks -include_generated_clocks clkudp_31_25M] -to [get_clocks -include_generated_clocks clk_62_5M]
#set_false_path -from [get_clocks -include_generated_clocks clk_125M] -to [get_clocks -include_generated_clocks clk_62_5M]

#set_false_path -from [get_clocks -include_generated_clocks clk_in_p] -to [get_clocks -include_generated_clocks gtrefclk]
#set_false_path -from [get_clocks -include_generated_clocks gtrefclk] -to [get_clocks -include_generated_clocks clk_in_p]
#create_clock -period 8 [get_ports gtrefclk_p]
#create_clock -period 8 [get_ports gtrefclk_n]

# SGMII interface

set_property PACKAGE_PIN AM7 [get_ports rxn]

# PHY reset
set_property PACKAGE_PIN AJ33 [get_ports phy_resetn]
set_property IOSTANDARD LVCMOS18 [get_ports phy_resetn]

# MDIO
set_property PACKAGE_PIN AK33 [get_ports mdio]
set_property IOSTANDARD LVCMOS18 [get_ports mdio]

set_property PACKAGE_PIN AH31 [get_ports mdc]
set_property IOSTANDARD LVCMOS18 [get_ports mdc]


set_property PACKAGE_PIN AV39 [get_ports update_speed]
set_property IOSTANDARD LVCMOS18 [get_ports update_speed]

set_property PACKAGE_PIN AW40 [get_ports config_board]
set_property IOSTANDARD LVCMOS18 [get_ports config_board]

set_property PACKAGE_PIN AP40 [get_ports pause_req_s]
set_property IOSTANDARD LVCMOS18 [get_ports pause_req_s]

set_property PACKAGE_PIN AR40 [get_ports reset_error]
set_property IOSTANDARD LVCMOS18 [get_ports reset_error]

set_property PACKAGE_PIN AV30 [get_ports {mac_speed[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {mac_speed[0]}]
set_property PACKAGE_PIN AY33 [get_ports {mac_speed[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {mac_speed[1]}]

set_property PACKAGE_PIN BA31 [get_ports gen_tx_data]
set_property IOSTANDARD LVCMOS18 [get_ports gen_tx_data]
set_property PACKAGE_PIN BA32 [get_ports chk_tx_data]
set_property IOSTANDARD LVCMOS18 [get_ports chk_tx_data]

set_false_path -through [get_nets sys_rst]
set_property PACKAGE_PIN AV40 [get_ports sys_rst]
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst]

set_property PACKAGE_PIN AG34 [get_ports serial_response]
set_property IOSTANDARD LVCMOS18 [get_ports serial_response]
set_property PACKAGE_PIN AD36 [get_ports tx_statistics_s]
set_property IOSTANDARD LVCMOS18 [get_ports tx_statistics_s]
set_property PACKAGE_PIN AD37 [get_ports rx_statistics_s]
set_property IOSTANDARD LVCMOS18 [get_ports rx_statistics_s]

##LED4
set_property PACKAGE_PIN AR35 [get_ports synchronization_done]
set_property IOSTANDARD LVCMOS18 [get_ports synchronization_done]
##LED_5
set_property PACKAGE_PIN AP41 [get_ports linkup]
set_property IOSTANDARD LVCMOS18 [get_ports linkup]




############################################################
# Ethernet      Constraints                              #
############################################################
# Transmitter clock period constraints: please do not relax
create_clock -name clkout0 -period 8.000 [get_ports gtrefclk_n]



#set axi_clk_name [get_clocks -of_objects [get_pins example_clocks/bufg_axi_clk/O]]

############################################################
# Input Delay constraints
############################################################
# these inputs are alll from either dip switchs or push buttons
# and therefore have no timing associated with them
set_false_path -from [get_ports config_board]
set_false_path -from [get_ports pause_req_s]
set_false_path -from [get_ports reset_error]
set_false_path -from [get_ports mac_speed[0]]
set_false_path -from [get_ports mac_speed[1]]
set_false_path -from [get_ports gen_tx_data]
set_false_path -from [get_ports chk_tx_data]

# no timing requirements but want the capture flops close to the IO
#set_max_delay -from [get_ports update_speed] 4 -datapath_only
# mdio has timing implications but slow interface so relaxed


# Ignore pause deserialiser as only present to prevent logic stripping
#set_false_path -from [get_ports pause_req*]



############################################################
# Output Delay constraints
############################################################


set_false_path -to [get_ports serial_response]
set_false_path -to [get_ports tx_statistics_s]
set_false_path -to [get_ports rx_statistics_s]



############################################################
# Ignore paths to resync flops
############################################################
#set_false_path -to [get_pins -hier -filter {NAME =~ */reset_sync*/PRE}]


############################################################
# FIFO Clock Crossing Constraints                          #
############################################################

# control signal is synched separately so this is a false path
set_max_delay -from [get_cells -hier -filter {name =~ *rx_fifo_i/rd_addr_reg[*]}] -to [get_cells -hier -filter {name =~ *fifo*wr_rd_addr_reg[*]}] 6 -datapath_only
set_max_delay -from [get_cells -hier -filter {name =~ *rx_fifo_i/wr_store_frame_tog_reg}] -to [get_cells -hier -filter {name =~ *fifo_i/resync_wr_store_frame_tog/data_sync_reg0}] 6 -datapath_only
set_max_delay -from [get_cells -hier -filter {name =~ *rx_fifo_i/update_addr_tog_reg}] -to [get_cells -hier -filter {name =~ *rx_fifo_i/sync_rd_addr_tog/data_sync_reg0}] 6 -datapath_only
set_max_delay -from [get_cells -hier -filter {name =~ *tx_fifo_i/rd_addr_txfer_reg[*]}] -to [get_cells -hier -filter {name =~ *fifo*wr_rd_addr_reg[*]}] 6 -datapath_only
set_max_delay -from [get_cells -hier -filter {name =~ *tx_fifo_i/wr_frame_in_fifo_reg}] -to [get_cells -hier -filter {name =~ *tx_fifo_i/resync_wr_frame_in_fifo/data_sync_reg0}] 6 -datapath_only
set_max_delay -from [get_cells -hier -filter {name =~ *tx_fifo_i/wr_frames_in_fifo_reg}] -to [get_cells -hier -filter {name =~ *tx_fifo_i/resync_wr_frames_in_fifo/data_sync_reg0}] 6 -datapath_only
set_max_delay -from [get_cells -hier -filter {name =~ *tx_fifo_i/frame_in_fifo_valid_tog_reg}] -to [get_cells -hier -filter {name =~ *tx_fifo_i/resync_fif_valid_tog/data_sync_reg0}] 6 -datapath_only
set_max_delay -from [get_cells -hier -filter {name =~ *tx_fifo_i/rd_txfer_tog_reg}] -to [get_cells -hier -filter {name =~ *tx_fifo_i/resync_rd_txfer_tog/data_sync_reg0}] 6 -datapath_only
set_max_delay -from [get_cells -hier -filter {name =~ *tx_fifo_i/rd_tran_frame_tog_reg}] -to [get_cells -hier -filter {name =~ *tx_fifo_i/resync_rd_tran_frame_tog/data_sync_reg0}] 6 -datapath_only




