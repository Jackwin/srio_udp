//------------------------------------------------------------------------------
// File         : tri_mode_ethernet_mac_0_example_design.v
// Author      : Xilinx Inc.
// -----------------------------------------------------------------------------
// (c) Copyright 2004-2013 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// -----------------------------------------------------------------------------
// Description:  This is the Verilog example design for the Tri-Mode
//                    Ethernet MAC core. It is intended that this example design
//                    can be quickly adapted and downloaded onto an FPGA to provide
//                    a real hardware test environment.
//
//                    This level:
//
//                    * Instantiates the FIFO Block wrapper, containing the
//                      block level wrapper and an RX and TX FIFO with an
//                      AXI-S interface;
//
//                    * Instantiates a simple AXI-S example design,
//                      providing an address swap and a simple
//                      loopback function;
//
//                    * Instantiates transmitter clocking circuitry
//                         -the User side of the FIFOs are clocked at gtx_clk
//                          at all times
//
//                    * Instantiates a state machine which drives the AXI Lite
//                      interface to bring the TEMAC up in the correct state
//
//                    * Serializes the Statistics vectors to prevent logic being
//                      optimized out
//
//                    * Ties unused inputs off to reduce the number of IO
//
//                    Please refer to the Datasheet, Getting Started Guide, and
//                    the Tri-Mode Ethernet MAC User Gude for further information.
//
//     --------------------------------------------------
//     | EXAMPLE DESIGN WRAPPER                                 |
//     |                                                                |
//     |                                                                |
//     |    -------------------      -------------------  |
//     |    |                      |      |                      |  |
//     |    |     Clocking      |      |      Resets        |  |
//     |    |                      |      |                      |  |
//     |    -------------------      -------------------  |
//     |              -------------------------------------|
//     |              |FIFO BLOCK WRAPPER                        |
//     |              |                                                |
//     |              |                                                |
//     |              |                  ----------------------|
//     |              |                  | SUPPORT LEVEL         |
//     | --------  |                  |                            |
//     | |        |  |                  |                            |
//     | | AXI  |->|------------->|                            |
//     | | LITE |  |                  |                            |
//     | |  SM  |  |                  |                            |
//     | |        |<-|<-------------|                            |
//     | |        |  |                  |                            |
//     | --------  |                  |                            |
//     |              |                  |                            |
//     | --------  |  ----------  |                            |
//     | |        |  |  |          |  |                            |
//     | |        |->|->|          |->|                            |
//     | | PAT  |  |  |          |  |                            |
//     | | GEN  |  |  |          |  |                            |
//     | |(ADDR |  |  |  AXI-S |  |                            |
//     | | SWAP)|  |  |  FIFO  |  |                            |
//     | |        |  |  |          |  |                            |
//     | |        |  |  |          |  |                            |
//     | |        |  |  |          |  |                            |
//     | |        |<-|<-|          |<-|                            |
//     | |        |  |  |          |  |                            |
//     | --------  |  ----------  |                            |
//     |              |                  |                            |
//     |              |                  ----------------------|
//     |              -------------------------------------|
//     --------------------------------------------------

//------------------------------------------------------

`timescale 1 ps/1 ps
`define UDP
`define MY_IP_ADDR              32'hc0a80006 // 192.168.0.6
`define MY_MAC_ADDR              48'hdd0504030201
//------------------------------------------------------------------------------
// The module declaration for the example_design level wrapper.
//------------------------------------------------------------------------------

(* DowngradeIPIdentifiedWarnings = "yes" *)
module tri_mode_ethernet_mac_0_example_design
(
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
    input [1:0]     mac_speed,
    input           update_speed,
    input           configuration_valid,
    //input            serial_command, // tied to pause_req_s
    input           config_board,
    output          serial_response,
    input           gen_tx_data,
    input           chk_tx_data,
    input           reset_error,

    // Data Interface
    output          clk_udp,
    output          reset_udp,
    input           udpdata_tready_in,
    output [31:0]   udpdata_tdata_out,
    output          udpdata_tvalid_out,
    output [3:0]    udpdata_tkeep_out,
    output          udpdata_tfirst_out,
    output          udpdata_tlast_out,
    output [15:0]   udpdata_length_out,

    output [7:0]    cmd_out,
    output          cmd_valid_out
);

    //----------------------------------------------------------------------------
    // internal signals used in this top level wrapper.
    //----------------------------------------------------------------------------

    // example design clocks
    wire                      gtx_clk_bufg;
    wire                      s_axi_aclk;
    wire                      rx_mac_aclk;
    wire                      tx_mac_aclk;
    // resets (and reset generation)
    wire                      s_axi_resetn;
    wire                      chk_resetn;

    wire                      gtx_resetn;

    wire                      rx_reset;
    wire                      tx_reset;

    wire                      glbl_rst_intn;

    wire  [7:0]             gmii_txd_int;
    wire                      gmii_tx_en_int;
    wire                      gmii_tx_er_int;
    wire    [7:0]             gmii_rxd_int;
    wire                        gmii_rx_dv_int;
    wire                        gmii_rx_er_int;

    // USER side RX AXI-S interface
    wire                      rx_fifo_clock;
    wire                      rx_fifo_resetn;

    wire  [7:0]             rx_axis_fifo_tdata;

    wire                      rx_axis_fifo_tvalid;
    wire                      rx_axis_fifo_tlast;
    wire                      rx_axis_fifo_tready;

    // USER side TX AXI-S interface
    wire                      tx_fifo_clock;
    wire                      tx_fifo_resetn;

    wire  [7:0]             tx_axis_fifo_tdata;

    wire                      tx_axis_fifo_tvalid;
    wire                      tx_axis_fifo_tlast;
    wire                      tx_axis_fifo_tready;

    // RX Statistics serialisation signals
    wire                      rx_statistics_valid;
    reg                        rx_statistics_valid_reg;
    wire  [27:0]            rx_statistics_vector;
    reg    [27:0]            rx_stats;
    reg    [29:0]            rx_stats_shift;
    reg                        rx_stats_toggle = 0;
    wire                      rx_stats_toggle_sync;
    reg                        rx_stats_toggle_sync_reg = 0;

    // TX Statistics serialisation signals
    wire                      tx_statistics_valid;
    reg                        tx_statistics_valid_reg;
    wire  [31:0]            tx_statistics_vector;
    reg    [31:0]            tx_stats;
    reg    [33:0]            tx_stats_shift;
    reg                        tx_stats_toggle = 0;
    wire                      tx_stats_toggle_sync;
    reg                        tx_stats_toggle_sync_reg = 0;

    // Pause interface DESerialisation
    reg    [18:0]            pause_shift;
    reg                        pause_req;
    reg    [15:0]            pause_val;

    // AXI-Lite interface
    wire  [11:0]            s_axi_awaddr;
    wire                      s_axi_awvalid;
    wire                      s_axi_awready;
    wire  [31:0]            s_axi_wdata;
    wire                      s_axi_wvalid;
    wire                      s_axi_wready;
    wire  [1:0]             s_axi_bresp;
    wire                      s_axi_bvalid;
    wire                      s_axi_bready;
    wire  [11:0]            s_axi_araddr;
    wire                      s_axi_arvalid;
    wire                      s_axi_arready;
    wire  [31:0]            s_axi_rdata;
    wire  [1:0]             s_axi_rresp;
    wire                      s_axi_rvalid;
    wire                      s_axi_rready;

    // set board defaults - only updated when reprogrammed
    reg                        enable_address_swap = 1;

    reg                        enable_phy_loopback = 0;

    //--------------------------------------------------------------------
    // signals for PCS_PMA
    //--------------------------------------------------------------------
        // clock generation signals for tranceiver
    wire            gtrefclk;                      // gtrefclk routed through an IBUFG.
    wire            gtrefclk_buf_i;                      // gtrefclk routed through an IBUFG.
    wire            txoutclk;                      // txoutclk from GT transceiver.
    wire            resetdone;                     // To indicate that the GT transceiver has completed its reset cycle
    wire            userclk;                        // 62.5MHz clock for GT transceiver Tx/Rx user clocks
    wire            userclk2;                      // 125MHz clock for core reference clock.


    // An independent clock source used as the reference clock for an
    // IDELAYCTRL (if present) and for the main GT transceiver reset logic.
    wire            independent_clock_bufg;
    wire                sys_clk_200m;

    wire                signal_detect;
     wire     [4:0]     configuration_vector;
     wire     [15:0]     an_adv_config_vector;
     wire                an_restart_config;
     wire     [15:0]     status_vector_int;

     wire          clk_enable;


 //--------------------------------------------------------------------------
    // signal tie offs
    wire  [7:0]             tx_ifg_delay = 0;     // not used in this example



    wire                      mdio_i;
    wire                      mdio_o;
    wire                      mdio_t;

// --------------------------------------------------------------------------
wire mmcm_locked;
wire gtx_resetdone;
// UDP signals
reg [31:0]            dest_ip_addr = 32'hddccbbaa;
reg [15:0]            dest_port = 32'd1024;
wire                    clk_32;
wire                    reset_32 = ~mmcm_locked;


// Debug
wire [0:0]            mmcm_locked_ila;
wire [0:0]            gtx_resetdone_ila;
wire [0:0]            synchronization_done_ila;
wire [0:0]            linkup_ila;
wire [0:0]            gen_tx_data_ila;
wire [0:0]            rx_axis_fifo_tvalid_ila;
wire [0:0]            rx_axis_fifo_tready_ila;
wire [0:0]            rx_axis_fifo_tlast_ila;
wire [0:0]            tx_data_gen_vio;
wire                    tx_data_gen;
wire [0:0]            arp_reply_out_ila;
wire [0:0]            arp_reply_ack_ila;
wire [0:0]            arp_ready_in_ila;

  //----------------------------------------------------------------------------
  // Begin the logic description
  //----------------------------------------------------------------------------

  // want to infer an IOBUF on the mdio port
  assign mdio = mdio_t ? 1'bz : mdio_o;

  assign mdio_i = mdio;


  // when the config_board button is pushed capture and hold the
  // state of the gne/chek tx_data inputs.  These values will persist until the
  // board is reprogrammed or config_board is pushed again
  always @(posedge gtx_clk_bufg)
  begin
      if (config_board) begin
          enable_address_swap    <= gen_tx_data;
      end
  end


  always @(posedge s_axi_aclk)
  begin
      if (config_board) begin
          enable_phy_loopback    <= chk_tx_data;
      end
  end


// route gtx_clk through a BUFGCE and onto global clock routing
BUFGCE bufg_gtx_clk (.I(userclk2), .CE  (1'b1), .O(gtx_clk_bufg));
assign     s_axi_aclk = userclk;


  //----------------------------------------------------------------------------
  // PHY Reset
  //----------------------------------------------------------------------------
  // the phy reset output (active low) needs to be held for at least 10x25MHZ cycles
    // this is derived using the 125MHz available and a 6 bit counter
    reg     [5:0]          phy_reset_count;
    reg                     phy_resetn_int;

    always @(posedge userclk2)
    begin
        if (!glbl_rst_intn) begin
            phy_resetn_int <= 0;
            phy_reset_count <= 0;
        end
        else begin
            if (!(&phy_reset_count)) begin
                phy_reset_count <= phy_reset_count + 1;
            end
            else begin
                phy_resetn_int <= 1;
            end
        end
    end

    assign phy_resetn = phy_resetn_int;
  //----------------------------------------------------------------------------
  // Generate the user side clocks for the axi fifos
  //----------------------------------------------------------------------------

  assign tx_fifo_clock = gtx_clk_bufg;
  assign rx_fifo_clock = gtx_clk_bufg;


  //----------------------------------------------------------------------------
  // Pipeline the gmii_tx outputs - this is only necessary for the example design
  // and can be removed when connected internally
  //----------------------------------------------------------------------------
 /* always @(posedge gtx_clk_bufg)
  begin
      gmii_txd          <= gmii_txd_int;
      gmii_tx_en        <= gmii_tx_en_int;
      gmii_tx_er        <= gmii_tx_er_int;
      gmii_rxd_int     <= gmii_rxd;
      gmii_rx_dv_int  <= gmii_rx_dv;
      gmii_rx_er_int  <= gmii_rx_er;
  end*/


  //----------------------------------------------------------------------------
  // Generate resets required for the fifo side signals etc
  //----------------------------------------------------------------------------

    tri_mode_ethernet_mac_0_example_design_resets example_resets
    (
        // clocks
        .s_axi_aclk         (s_axi_aclk),
        .gtx_clk             (gtx_clk_bufg),

        // asynchronous resets
        .glbl_rst            (glbl_rst),
        .reset_error        (reset_error),
        .rx_reset            (rx_reset),
        .tx_reset            (tx_reset),

        // asynchronous reset output

        .glbl_rst_intn     (glbl_rst_intn),
        // synchronous reset outputs


        .gtx_resetn         (gtx_resetn),

        .s_axi_resetn      (s_axi_resetn),
        .chk_resetn         (chk_resetn)
    );


    // generate the user side resets for the axi fifos

    assign tx_fifo_resetn = gtx_resetn;
    assign rx_fifo_resetn = gtx_resetn;


  //----------------------------------------------------------------------------
  // Serialize the stats vectors
  // This is a single bit approach, retimed onto gtx_clk
  // this code is only present to prevent code being stripped..
  //----------------------------------------------------------------------------

  // RX STATS

  // first capture the stats on the appropriate clock
  always @(posedge rx_mac_aclk)
  begin
      rx_statistics_valid_reg <= rx_statistics_valid;
      if (!rx_statistics_valid_reg & rx_statistics_valid) begin
          rx_stats <= rx_statistics_vector;
          rx_stats_toggle <= !rx_stats_toggle;
      end
  end

  tri_mode_ethernet_mac_0_sync_block rx_stats_sync (
      .clk                  (gtx_clk_bufg),
      .data_in             (rx_stats_toggle),
      .data_out            (rx_stats_toggle_sync)
  );

  always @(posedge gtx_clk_bufg)
  begin
      rx_stats_toggle_sync_reg <= rx_stats_toggle_sync;
  end

  // when an update is rxd load shifter (plus start/stop bit)
  // shifter always runs (no power concerns as this is an example design)
  always @(posedge gtx_clk_bufg)
  begin
      if (rx_stats_toggle_sync_reg != rx_stats_toggle_sync) begin
          rx_stats_shift <= {1'b1, rx_stats, 1'b1};
      end
      else begin
          rx_stats_shift <= {rx_stats_shift[28:0], 1'b0};
      end
  end

  assign rx_statistics_s = rx_stats_shift[29];

  // TX STATS

  // first capture the stats on the appropriate clock
  always @(posedge tx_mac_aclk)
  begin
      tx_statistics_valid_reg <= tx_statistics_valid;
      if (!tx_statistics_valid_reg & tx_statistics_valid) begin
          tx_stats <= tx_statistics_vector;
          tx_stats_toggle <= !tx_stats_toggle;
      end
  end

  tri_mode_ethernet_mac_0_sync_block tx_stats_sync (
      .clk                  (gtx_clk_bufg),
      .data_in             (tx_stats_toggle),
      .data_out            (tx_stats_toggle_sync)
  );

  always @(posedge gtx_clk_bufg)
  begin
      tx_stats_toggle_sync_reg <= tx_stats_toggle_sync;
  end

  // when an update is txd load shifter (plus start bit)
  // shifter always runs (no power concerns as this is an example design)
  always @(posedge gtx_clk_bufg)
  begin
      if (tx_stats_toggle_sync_reg != tx_stats_toggle_sync) begin
          tx_stats_shift <= {1'b1, tx_stats, 1'b1};
      end
      else begin
          tx_stats_shift <= {tx_stats_shift[32:0], 1'b0};
      end
  end

  assign tx_statistics_s = tx_stats_shift[33];

  //----------------------------------------------------------------------------
  // DSerialize the Pause interface
  // This is a single bit approachtimed on gtx_clk
  // this code is only present to prevent code being stripped..
  //----------------------------------------------------------------------------
  // the serialised pause info has a start bit followed by the quanta and a stop bit
  // capture the quanta when the start bit hits the msb and the stop bit is in the lsb
  always @(posedge gtx_clk_bufg)
  begin
      pause_shift <= {pause_shift[17:0], pause_req_s};
  end

  always @(posedge gtx_clk_bufg)
  begin
      if (pause_shift[18] == 1'b0 & pause_shift[17] == 1'b1 & pause_shift[0] == 1'b1) begin
          pause_req <= 1'b1;
          pause_val <= pause_shift[16:1];
      end
      else begin
          pause_req <= 1'b0;
          pause_val <= 0;
      end
  end

  //----------------------------------------------------------------------------
  // Instantiate the AXI-LITE Controller
  //----------------------------------------------------------------------------

    tri_mode_ethernet_mac_0_axi_lite_sm axi_lite_controller (
        .s_axi_aclk                         (s_axi_aclk),
        .s_axi_resetn                      (s_axi_resetn),

        .mac_speed                          (mac_speed),
        .update_speed                      (update_speed),    // may need glitch protection on this..
        .serial_command                    (pause_req_s),
        .serial_response                  (serial_response),

        .phy_loopback                      (enable_phy_loopback),

        .s_axi_awaddr                      (s_axi_awaddr),
        .s_axi_awvalid                     (s_axi_awvalid),
        .s_axi_awready                     (s_axi_awready),

        .s_axi_wdata                        (s_axi_wdata),
        .s_axi_wvalid                      (s_axi_wvalid),
        .s_axi_wready                      (s_axi_wready),

        .s_axi_bresp                        (s_axi_bresp),
        .s_axi_bvalid                      (s_axi_bvalid),
        .s_axi_bready                      (s_axi_bready),

        .s_axi_araddr                      (s_axi_araddr),
        .s_axi_arvalid                     (s_axi_arvalid),
        .s_axi_arready                     (s_axi_arready),

        .s_axi_rdata                        (s_axi_rdata),
        .s_axi_rresp                        (s_axi_rresp),
        .s_axi_rvalid                      (s_axi_rvalid),
        .s_axi_rready                      (s_axi_rready)
    );

  //----------------------------------------------------------------------------
  // Instantiate the TRIMAC core fifo block wrapper
  //----------------------------------------------------------------------------
  tri_mode_ethernet_mac_0_fifo_block trimac_fifo_block (
        .gtx_clk                             (gtx_clk_bufg),

        // asynchronous reset
        .glbl_rstn                          (glbl_rst_intn),
        .rx_axi_rstn                        (1'b1),
        .tx_axi_rstn                        (1'b1),

        // Receiver Statistics Interface
        //---------------------------------------
        .rx_mac_aclk                        (rx_mac_aclk),
        .rx_reset                            (rx_reset),
        .rx_statistics_vector            (rx_statistics_vector),
        .rx_statistics_valid             (rx_statistics_valid),

        // Receiver (AXI-S) Interface
        //----------------------------------------
        .rx_fifo_clock                     (rx_fifo_clock),
        .rx_fifo_resetn                    (rx_fifo_resetn),
        .rx_axis_fifo_tdata              (rx_axis_fifo_tdata),
        .rx_axis_fifo_tvalid             (rx_axis_fifo_tvalid),
        .rx_axis_fifo_tready             (rx_axis_fifo_tready),
        .rx_axis_fifo_tlast              (rx_axis_fifo_tlast),

        // Transmitter Statistics Interface
        //------------------------------------------
        .tx_mac_aclk                        (tx_mac_aclk),
        .tx_reset                            (tx_reset),
        .tx_ifg_delay                      (tx_ifg_delay),
        .tx_statistics_vector            (tx_statistics_vector),
        .tx_statistics_valid             (tx_statistics_valid),

        // Transmitter (AXI-S) Interface
        //-------------------------------------------
        .tx_fifo_clock                     (tx_fifo_clock),
        .tx_fifo_resetn                    (tx_fifo_resetn),
        .tx_axis_fifo_tdata              (tx_axis_fifo_tdata),
        .tx_axis_fifo_tvalid             (tx_axis_fifo_tvalid),
        .tx_axis_fifo_tready             (tx_axis_fifo_tready),
        .tx_axis_fifo_tlast              (tx_axis_fifo_tlast),



        // MAC Control Interface
        //------------------------
        .pause_req                          (pause_req),
        .pause_val                          (pause_val),

        // GMII Interface
        //-----------------
        .gmii_txd                            (gmii_txd_int),
        .gmii_tx_en                         (gmii_tx_en_int),
        .gmii_tx_er                         (gmii_tx_er_int),
        .gmii_rxd                            (gmii_rxd_int),
        .gmii_rx_dv                         (gmii_rx_dv_int),
        .gmii_rx_er                         (gmii_rx_er_int),
        .clk_enable                         (clk_enable),
        .speedis100                         (speedis100),
        .speedis10100                      (speedis10100),

        // MDIO Interface
        //---------------
        .mdc                                  (mdc),
        .mdio_i                              (mdio_i),
        .mdio_o                              (mdio_o),
        .mdio_t                              (mdio_t),

        // AXI-Lite Interface
        //---------------
        .s_axi_aclk                         (s_axi_aclk),
        .s_axi_resetn                      (s_axi_resetn),

        .s_axi_awaddr                      (s_axi_awaddr),
        .s_axi_awvalid                     (s_axi_awvalid),
        .s_axi_awready                     (s_axi_awready),

        .s_axi_wdata                        (s_axi_wdata),
        .s_axi_wvalid                      (s_axi_wvalid),
        .s_axi_wready                      (s_axi_wready),

        .s_axi_bresp                        (s_axi_bresp),
        .s_axi_bvalid                      (s_axi_bvalid),
        .s_axi_bready                      (s_axi_bready),

        .s_axi_araddr                      (s_axi_araddr),
        .s_axi_arvalid                     (s_axi_arvalid),
        .s_axi_arready                     (s_axi_arready),

        .s_axi_rdata                        (s_axi_rdata),
        .s_axi_rresp                        (s_axi_rresp),
        .s_axi_rvalid                      (s_axi_rvalid),
        .s_axi_rready                      (s_axi_rready)

    );


  //----------------------------------------------------------------------------
  //  Instantiate the address swapping module and simple pattern generator
  //----------------------------------------------------------------------------
  `ifndef UDP
    tri_mode_ethernet_mac_0_basic_pat_gen basic_pat_gen_inst (
    .axi_tclk                            (tx_fifo_clock),
    .axi_tresetn                        (tx_fifo_resetn),
    .check_resetn                      (chk_resetn),

    .enable_pat_gen                    (gen_tx_data),
    .enable_pat_chk                    (chk_tx_data),
    .enable_address_swap             (enable_address_swap),
    .speed                                (mac_speed),

    .rx_axis_tdata                     (rx_axis_fifo_tdata),
    .rx_axis_tvalid                    (rx_axis_fifo_tvalid),
    .rx_axis_tlast                     (rx_axis_fifo_tlast),
    .rx_axis_tuser                     (1'b0), // the FIFO drops all bad frames
    .rx_axis_tready                    (rx_axis_fifo_tready),

    .tx_axis_tdata                     (tx_axis_fifo_tdata),
    .tx_axis_tvalid                    (tx_axis_fifo_tvalid),
    .tx_axis_tlast                     (tx_axis_fifo_tlast),
    .tx_axis_tready                    (tx_axis_fifo_tready),

    .frame_error                        (),
    .activity_flash                    ()
    );
  //-----------------------------------------------------------------------------
  // Generate UDP package
  //-----------------------------------------------------------------------------
  `else
     wire arp_reply_out;
     wire arp_reply_ack;
     wire [31:0] remote_ip_addr_out;
     wire [47:0] remote_mac_addr_out;
     assign clk_udp = clk_32;
     assign reset_udp = reset_32;
    ip_packet_gen ip_packet_gen_module (

     .local_IP_in         (`MY_IP_ADDR),
     .local_MAC_in        (`MY_MAC_ADDR),

          //ARP Get the remote ip and mac
     .remote_ip_addr_in (remote_ip_addr_out),
     .remote_mac_addr_in(remote_mac_addr_out),
     .arp_reply_in(arp_reply_out),
     .arp_reply_ack_out (arp_reply_ack),
     // IP signals
     .clk_32(clk_32),
     .reset_32 (reset_32),
     .enable_ip_data_gen(tx_data_gen),
     .tcp_ctrl_type('h0),
     .dest_ip_addr(dest_ip_addr),
     .dest_port(dest_port),

     .clk_8(tx_fifo_clock),
     .reset_8(~tx_fifo_resetn),
     .axis_tdata_out(tx_axis_fifo_tdata),
     .axis_tvalid_out(tx_axis_fifo_tvalid),
     .axis_tlast_out(tx_axis_fifo_tlast),
     .axis_tready_in(tx_axis_fifo_tready)
  );

recv_top recv_top_i
(
     .clk_8(tx_fifo_clock),
     .reset_8          (~tx_fifo_resetn),
     .local_mac_addr      (`MY_MAC_ADDR),
     .local_ip_addr        (`MY_IP_ADDR), //192.168.0.6  c0a80006

     .axis_tdata_in(rx_axis_fifo_tdata),
     .axis_tvalid_in(rx_axis_fifo_tvalid),
     .axis_tlast_in(rx_axis_fifo_tlast),
     .axis_tready_o(rx_axis_fifo_tready),
     // Todo Add reply_ready in send_top.v
     .reply_ready_in      (1'b1),
     .remote_ip_addr_out (remote_ip_addr_out),
     .remote_mac_addr_out(remote_mac_addr_out),
     //TODO add arp_reply_ack
     .arp_reply_ack_in    (arp_reply_ack),
     .arp_reply_out (arp_reply_out),

     .clk_32                 (clk_32),
     .reset_32              (reset_32),
     .udpdata_tready_in  (udpdata_tready_in),
     .udpdata_tdata_out  (udpdata_tdata_out),
     .udpdata_tfirst_out (udpdata_tfirst_out),
     .udpdata_tvalid_out (udpdata_tvalid_out),
     .udpdata_tkeep_out  (udpdata_tkeep_out),
     .udpdata_tlast_out  (udpdata_tlast_out),
     .udp_length_out      (udpdata_length_out),
     .cmd_out            (cmd_out),
     .cmd_valid_out      (cmd_valid_out)

);

assign arp_reply_out_ila[0] = arp_reply_out;
assign arp_reply_ack_ila[0] = arp_reply_ack;
assign arp_ready_in_ila[0] = 1'b1;
/*
ila_1 ila_arp (
          .clk(tx_fifo_clock), // input wire clk
          .probe0(remote_ip_addr_out[7:0]), // input wire [7:0]  probe0
          .probe1(arp_reply_out_ila), // input wire [0:0]  probe1
          .probe2(arp_reply_ack_ila), // input wire [0:0]  probe2
          .probe3(arp_ready_in_ila) // input wire [0:0]  probe3
     );
     */

`endif

//------------------------------------------------------------------------------
//                                  PCS_PMA
//------------------------------------------------------------------------------

     IBUFDS #(
        .DIFF_TERM("FALSE"),         // Differential Termination
        .IBUF_LOW_PWR("TRUE"),      // Low power="TRUE", Highest performance="FALSE"
        .IOSTANDARD("DEFAULT")      // Specify the input I/O standard
    ) IBUFDS_sys_clk_200m (
        .O(sys_clk_200m),  // Buffer output
        .I(clk_in_p),  // Diff_p buffer input (connect directly to top-level port)
        .IB(clk_in_n) // Diff_n buffer input (connect directly to top-level port)
    );
    // Route independent_clock input through a BUFG
    BUFG  bufg_independent_clock (
        .I            (sys_clk_200m),
        .O            (independent_clock_bufg)
    );

 //----------------------------------------------------------------------------
// Instantiate the Core Block (core wrapper).
//----------------------------------------------------------------------------

gig_ethernet_pcs_pma_0_support
 core_support_i
 (

    .gtrefclk_p             (gtrefclk_p),
    .gtrefclk_n             (gtrefclk_n),
    .gtrefclk_out           (),
    .txp                    (txp),
    .txn                    (txn),
    .rxp                    (rxp),
    .rxn                    (rxn),
    .mmcm_locked_out        (mmcm_locked),
    .userclk_out            (userclk),
    .userclk2_out           (userclk2),
    .clk_32_out             (clk_32),
    .rxuserclk_out          (),
    .rxuserclk2_out                        (rxuserclk2),
    .independent_clock_bufg                (independent_clock_bufg),
    .pma_reset_out                            (),
    .resetdone                                 (gtx_resetdone),

    .sgmii_clk_r                            (),
    .sgmii_clk_f                            (),
    .sgmii_clk_en                             (clk_enable),
    .gmii_txd                                  (gmii_txd_int),
    .gmii_tx_en                                (gmii_tx_en_int),
    .gmii_tx_er                                (gmii_tx_er_int),
    .gmii_rxd                                  (gmii_rxd_int),
    .gmii_rx_dv                                (gmii_rx_dv_int),
    .gmii_rx_er                                (gmii_rx_er_int),
    .gmii_isolate                             (gmii_isolate),
    .configuration_vector                  (configuration_vector),
    //.configuration_valid                    (configuration_valid),
    .an_interrupt                             (an_interrupt),
    .an_adv_config_vector                  (an_adv_config_vector),
    //.an_adv_config_val                      (1'b0),
    .an_restart_config                      (an_restart_config),
    .speed_is_10_100                         (speedis10100),
    .speed_is_100                             (speedis100),
    .status_vector                            (status_vector_int),
    .reset                                      (glbl_rst),


    .signal_detect                            (signal_detect),
    .gt0_qplloutclk_out                 (),
    .gt0_qplloutrefclk_out             ()
     );




     //link_timer_value <= "000110010";
     assign configuration_vector = 5'b10000;  //[4]AN enable,[3]Isolate disabled,[2]Powerdowndisabled,[1]loopback disabled, [0] Unidirectional disabled
     assign signal_detect = 1'b1;
     assign  an_adv_config_vector = 16'b0000000000100001;
     assign  an_restart_config     = 1'b0;

     assign synchronization_done = status_vector_int[1];
     assign linkup = status_vector_int[0];

//------------------------------- Debug ------------------------------

assign mmcm_locked_ila[0] = mmcm_locked;
assign gtx_resetdone_ila[0] = gtx_resetdone;
assign synchronization_done_ila[0] = synchronization_done;
assign linkup_ila[0] = linkup;
assign gen_tx_data_ila[0] = gen_tx_data;
assign rx_axis_fifo_tvalid_ila[0] = rx_axis_fifo_tvalid;
assign rx_axis_fifo_tlast_ila[0] = rx_axis_fifo_tlast;
assign rx_axis_fifo_tready_ila[0] = rx_axis_fifo_tready;
assign tx_data_gen = tx_data_gen_vio[0];
/*
ila_tx tx_ila (
     .clk(tx_fifo_clock),
     .probe0(mmcm_locked_ila),
     .probe1(gtx_resetdone_ila),
     .probe2(synchronization_done_ila),
     .probe3(linkup_ila),
  .probe4(gen_tx_data_ila),
  .probe5(tx_axis_fifo_tdata),
  .probe6(tx_axis_fifo_tvalid),
  .probe7(tx_axis_fifo_tlast)
     );

ila_rx ila_rx_i (
          .clk(tx_fifo_clock), // input wire clk
          .probe0(rx_axis_fifo_tdata), // input wire [7:0]  probe0
          .probe1(rx_axis_fifo_tvalid_ila), // input wire [0:0]  probe1
          .probe2(rx_axis_fifo_tlast_ila), // input wire [0:0]  probe2
          .probe3(rx_axis_fifo_tready_ila) // input wire [0:0]  probe3
     );

vio_tx_gen vio_tx_gen_i (
  .clk(tx_fifo_clock),                     // input wire clk
  .probe_out0(tx_data_gen_vio)  // output wire [0 : 0] probe_out0
);
*/

endmodule

