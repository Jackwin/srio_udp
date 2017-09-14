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
    //input         serial_command, // tied to pause_req_s
    input           config_board,
    output          serial_response,
    input           gen_tx_data,
    input           chk_tx_data,
    input           reset_error,
   

    //SRIO interface
    // Clocks and Resets
    input            srio_refclkp,              // MMCM reference clock
    input            srio_refclkn,              // MMCM reference clock

    // high-speed IO
    input           srio_rxn0,              // Serial Receive Data
    input           srio_rxp0,              // Serial Receive Data
    input           srio_rxn1,              // Serial Receive Data
    input           srio_rxp1,              // Serial Receive Data
    input           srio_rxn2,              // Serial Receive Data
    input           srio_rxp2,              // Serial Receive Data
    input           srio_rxn3,              // Serial Receive Data
    input           srio_rxp3,              // Serial Receive Data


    output          srio_txn0,              // Serial Transmit Data
    output          srio_txp0,              // Serial Transmit Data
    output          srio_txn1,              // Serial Transmit Data
    output          srio_txp1,              // Serial Transmit Data

    output          srio_txn2,              // Serial Transmit Data
    output          srio_txp2,              // Serial Transmit Data
    output          srio_txn3,              // Serial Transmit Data
    output          srio_txp3,              // Serial Transmit Data

    output  [1:0]   srio_led

);

wire                clk_udp;
wire                reset_udp;
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
    .configuration_valid (1'b1),
    .config_board        (config_board),
    .serial_response     (serial_response),
    .gen_tx_data         (gen_tx_data),
    .chk_tx_data         (chk_tx_data),
    .reset_error         (reset_error),
    .frame_error         (),
    .frame_errorn        (),
    .activity_flash      (),
    .activity_flashn     (),

    // Data interface
    .clk_udp             (clk_udp),
    .reset_udp           (reset_udp),
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
    .sys_clkp           (srio_refclkp),
    .sys_clkn           (srio_refclkn),
    .sys_rst_n          (~glbl_rst),
    .srio_rxn0          (srio_rxn0),
    .srio_rxp0          (srio_rxp0),
    .srio_rxn1          (srio_rxn1),
    .srio_rxp1          (srio_rxp1),
    .srio_rxn2          (srio_rxn2),
    .srio_rxp2          (srio_rxp2),
    .srio_rxn3          (srio_rxn3),
    .srio_rxp3          (srio_rxp3),

    .srio_txn0          (srio_txn0),
    .srio_txp0          (srio_txp0),
    .srio_txn1          (srio_txn1),
    .srio_txp1          (srio_txp1),
    .srio_txn2          (srio_txn2),
    .srio_txp2          (srio_txp2),
    .srio_txn3          (srio_txn3),
    .srio_txp3          (srio_txp3),

    .srio_led           (srio_led),

    .clk_srio           (clk_srio),
    .reset_srio         (reset_srio),
    .user_tdata_in      (srio_user_tdata),
    .user_tvalid_in     (srio_user_tvalid),
    .user_tfirst_in     (srio_user_tfirst),
    .user_tkeep_in      (srio_user_tkeep),
    .user_tlen_in       (srio_user_tlen),
    .user_tlast_in      (srio_user_tlast),
    .user_tready_out    (srio_user_tready),
    .ack_o()

);

udp2srio_interface udp2srio_interface_i
(
    .clk_udp         (clk_udp),
    .reset_udp       (reset_udp),
    .udp_data_in     (udp_data_in),
    .udp_valid_in    (udp_valid_in),
    .udp_first_in    (udp_first_in),
    .udp_keep_in     (udp_keep_in),
    .udp_last_in     (udp_last_in),
    .udp_length_in   (udp_length_in),
    .udp_ready_out   (udp_ready_out),

    .clk_srio       (clk_srio),
    .reset_srio     (reset_srio),
    .srio_ready_in  (srio_ready_in),
    .nwr_req_out     (nwr_req_out),
    .srio_length_out(srio_length_out),
    .srio_data_out  (srio_data_out),
    .srio_valid_out (srio_valid_out),
    .srio_first_out (srio_first_out),
    .srio_keep_out  (srio_keep_out),
    .srio_last_out  (srio_last_out)
);




endmodule