`timescale 1ps/1ps


module ethernet_sim ();
reg         gtrefclk_p;
wire        gtrefclk_n;
reg         glbl_rst;
reg         clk_in_p;
wire        clk_in_n;
wire        txp;
wire        txn;
wire        rxp;
wire        rxn;

wire        synchronization_done;
wire        linkup;

initial begin
    clk_in_p = 0;
    forever
    #2500 clk_in_p = ~clk_in_p;
end
assign clk_in_n = ~clk_in_p;

initial begin
    gtrefclk_p = 0;
    forever
    #4000 gtrefclk_p = ~gtrefclk_p;
end
assign gtrefclk_n = ~gtrefclk_p;



tri_mode_ethernet_mac_0_example_design dut
(
    .glbl_rst(),
    .phy_resetn,

//200MHz input clock
    .clk_in_p(),
    .clk_in_n(),

    .gtrefclk_p,
    .gtrefclk_n,
    .txp,
    .txn,
    .rxp,
    .rxn,

.synchronization_done,
.linkup,

// clock from internal phy
// .      gtx_clk,
//.      clk_enable,
//.    speedis100,
// .    speedis10100,


// MDIO Interface
//---------------
inout         mdio,
.    mdc,


// Serialised statistics vectors
//------------------------------
.    tx_statistics_s,
.    rx_statistics_s,

// Serialised Pause interface controls
//------------------------------------
.      pause_req_s,

// Main example design controls
//-----------------------------
input  [1:0]  mac_speed,
.      update_speed,
.      configuration_valid,
//.      serial_command, // tied to pause_req_s
.      config_board,
.    serial_response,
.      gen_tx_data,
.      chk_tx_data,
.      reset_error,
.    frame_error,
.    frame_errorn,
.    activity_flash,
.    activity_flashn

    );

endmodule