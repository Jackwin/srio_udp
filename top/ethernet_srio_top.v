`timescale 1ps/1ps

module ethernet_srio_top (

    // Ethernet interface
    // asynchronous reset
    input           sys_rst,
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
wire [31:0]         udpdata_tdata;
wire                udpdata_tvalid;
wire [3:0]          udpdata_tkeep;
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

wire                nwr_req_out;
wire                self_check_in;
wire                nwr_ready_out;
wire                nwr_busy_out;
wire                nwr_done_out;

wire [7:0]          cmd_data;
wire                cmd_valid;


tri_mode_ethernet_mac_0_example_design tri_mode_ethernet_mac_0_example_design_i
(
    //Physical Interface
    .glbl_rst            (sys_rst),
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

    // Data interface
    .clk_udp             (clk_udp),
    .reset_udp           (reset_udp),
    .udpdata_tready_in   (udpdata_tready),
    .udpdata_tdata_out   (udpdata_tdata),
    .udpdata_tvalid_out  (udpdata_tvalid),
    .udpdata_tkeep_out   (udpdata_tkeep),
    .udpdata_tfirst_out  (udpdata_tfirst),
    .udpdata_tlast_out   (udpdata_tlast),
    .udpdata_length_out  (udpdata_length),

    .cmd_out             (cmd_data),
    .cmd_valid_out       (cmd_valid)
);



srio_example_top_srio_gen2_0 srio_example_top_srio_gen2_0_i
(
    .sys_clkp           (srio_refclkp),
    .sys_clkn           (srio_refclkn),
    .sys_rst            (sys_rst),
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
    .self_check_in      (),
    .rapidIO_ready_out  (),
    .nwr_req_in         (nwr_req_out),
    .nwr_ready_out      (),
    .nwr_busy_out       (),
    .nwr_done_out       (),

    //TODO how to get the addr
    .user_taddr_in      ('h0),
    .user_tdata_in      (srio_user_tdata),
    .user_tvalid_in     (srio_user_tvalid),
    .user_tfirst_in     (srio_user_tfirst),
    .user_tkeep_in      (srio_user_tkeep),
    .user_tlen_in       (srio_user_tlen),
    .user_tlast_in      (srio_user_tlast),
    .user_tready_out    (srio_user_tready),
    .ack_o()

);

/*
udp2srio_interface udp2srio_interface_i
(
    .clk_udp         (clk_udp),
    .reset_udp       (reset_udp),
    .udp_data_in     (udpdata_tdata),
    .udp_valid_in    (udpdata_tvalid),
    .udp_first_in    (udpdata_tfirst),
    .udp_keep_in     (udpdata_tkeep),
    .udp_last_in     (udpdata_tlast),
    .udp_length_in   (udpdata_length),
    .udp_ready_out   (udpdata_tready),

    .clk_srio       (clk_srio),
    .reset_srio     (reset_srio),
    .srio_ready_in  (srio_user_tready),
    .nwr_req_out     (nwr_req_out),
    .srio_length_out(srio_user_tlen),
    .srio_data_out  (srio_user_tdata),
    .srio_valid_out (srio_user_tvalid),
    .srio_first_out (srio_user_tfirst),
    .srio_keep_out  (srio_user_tkeep),
    .srio_last_out  (srio_user_tlast)
);
*/
/*
wire [0:0]      udpdata_tvalid_ila;
wire [0:0]      udpdata_tfirst_ila;
wire [0:0]      udpdata_tlast_ila;
wire [0:0]      udpdata_tready_ila;
assign udpdata_tvalid_ila[0] = udpdata_tvalid;
assign udpdata_tfirst_ila[0] = udpdata_tfirst;
assign udpdata_tlast_ila[0] = udpdata_tlast;
assign udpdata_tready_ila[0] = udpdata_tready;

ila_udp_top ila_udp_top_i (
    .clk(clk_udp), // input wire clk
    .probe0(udpdata_tdata), // input wire [31:0]  probe0
    .probe1(udpdata_tvalid_ila), // input wire [0:0]  probe1
    .probe2(udpdata_tfirst_ila), // input wire [0:0]  probe2
    .probe3(udpdata_tkeep), // input wire [3:0]  probe3
    .probe4(udpdata_tlast), // input wire [0:0]  probe4
    .probe5(udpdata_length[14:0]), // input wire [14:0]  probe5
    .probe6(udpdata_tready_ila) // input wire [0:0]  probe6
);
*/




endmodule