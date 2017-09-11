`timescale 1ps/1ps

module ethernet_srio_top (

    // Ethernet interface
    // asynchronous reset
    input           glbl_rst,
    output          phy_resetn,

    //200MHz input clock
    input           clk_in_p,
    input           clk_in_n,

    input           gtrefclk_p,
    input           gtrefclk_n,
    output          txp,
    output          txn,
    input           rxp,
    input           rxn,

    output          synchronization_done,
    output          linkup,

    // MDIO Interface
    //---------------
    inout           mdio,
    output          mdc,
    // Serialised statistics vectors
    //------------------------------
    output          tx_statistics_s,
    output          rx_statistics_s,

    // Serialised Pause interface controls
    //------------------------------------
    input           pause_req_s,

    // Main example design controls
    //-----------------------------
    input  [1:0]    mac_speed,
    input           update_speed,
    input           configuration_valid,
    //input         serial_command, // tied to pause_req_s
    input           config_board,
    output          serial_response,
    input           gen_tx_data,
    input           chk_tx_data,
    input           reset_error,
    output          frame_error,
    output          frame_errorn,
    output          activity_flash,
    output          activity_flashn,

    //SRIO interface
    // Clocks and Resets
    input            srio_refclkp,              // MMCM reference clock
    input            srio_refclkn,              // MMCM reference clock

    // high-speed IO
    input           srio_rxn0,              // Serial Receive Data
    input           srio_rxp0,              // Serial Receive Data

    output          srio_txn0,              // Serial Transmit Data
    output          srio_txp0,              // Serial Transmit Data

    //input           sim_train_en,           // Set this only when simulating to reduce the size of counters
       `ifdef SIM
    output [3:0]        led0
    `else
    output  [1:0]   led0
    `endif

);

wire                udpdata_tready;
wire [63:0]         udpdata_tdata;
wire                udpdata_tvalid;
wire [7:0]          udpdata_tkeep;
wire                udpdata_tlast;
wire                udpdata_tfirst;
wire [15:0]         udpdata_length;

wire [63:0]         srio_user_tdata;
wire                srio_user_tvalid;
wire                srio_user_tfirst;
wire [7:0]          srio_user_tkeep;
wire                srio_user_tlast;
wire                srio_user_tready;
wire [15:0]         srio_user_tlen;

tri_mode_ethernet_mac_0_example_design tri_mode_ethernet_mac_0_example_design_i
(
    //Physical Interface
    .glbl_rst            (glbl_rst),
    .phy_resetn          (phy_resetn),
    .clk_in_p            (clk_in_p),
    .clk_in_n            (clk_in_n),
    .gtrefclk_p          (gtrefclk_p),
    .gtrefclk_n          (gtrefclk_n),
    .txp                 (txp),
    .txn                 (txn),
    .rxp                 (rxp),
    .rxn                 (rxn),

    .synchronization_done (synchronization_done),
    .linkup              (linkup),
    .mdio                (mdio),
    .mdc                 (mdc),

    .tx_statistics_s     (tx_statistics_s),
    .rx_statistics_s     (rx_statistics_s),

    .pause_req_s         (pause_req_s),
    .mac_speed           (mac_speed),
    .update_speed        (update_speed),
    .configuration_valid (configuration_valid),
    .config_board        (config_board),
    .serial_response     (serial_response),
    .gen_tx_data         (gen_tx_data),
    .chk_tx_data         (chk_tx_data),
    .reset_error         (reset_error),
    .frame_error         (frame_error),
    .frame_errorn        (frame_errorn),
    .activity_flash      (activity_flash),
    .activity_flashn     (activity_flashn),

    // Data interface
    .udpdata_tready_in   (udpdata_tready),
    .udpdata_tdata_out   (udpdata_tdata),
    .udpdata_tvalid_out  (udpdata_tvalid),
    .udpdata_tkeep_out   (udpdata_tkeep),
    .udpdata_tfirst_out  (udpdata_tfirst),
    .udpdata_tlast_out   (udpdata_tlast),
    .udpdata_length_out  (udpdata_length)
);


srio_example_top_srio_gen2_0 srio_example_top_srio_gen2_0_i
(
    .sys_clkp    (srio_refclkp),
    .sys_clkn    (srio_refclkn),
    .sys_rst_n     (~glbl_rst),
    .srio_rxn0   (srio_rxn0),
    .srio_rxp0   (srio_rxp0),
    .srio_txn0   (srio_txn0),
    .srio_txp0   (srio_txp0),
    .user_tdata_in (srio_user_tdata),
    .user_tvalid_in (srio_user_tvalid),
    .user_tfirst_in(srio_user_tfirst),
    .user_tkeep_in(srio_user_tkeep),
    .user_tlen_in(srio_user_tlen),
    .user_tlast_in(srio_user_tlast),
    .user_tready_out(srio_user_tready),
    .ack_o()

    );

endmodule