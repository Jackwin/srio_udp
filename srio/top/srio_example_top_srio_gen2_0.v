//
// (c) Copyright 2010 - 2014 Xilinx, Inc. All rights reserved.
//
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
//     PART OF THIS FILE AT ALL TIMES.
`timescale 1ps/1ps
(* DowngradeIPIdentifiedWarnings = "yes" *)

//`define SIM
module srio_example_top_srio_gen2_0 #(
    parameter MIRROR                    = 0,
    `ifdef SIM
    parameter SIM_1                     = 1,
    `else
    parameter SIM_1                     = 0,
    `endif
    parameter SIM_VERBOSE               = 0, // If set, generates unsynthesizable reporting
    parameter VALIDATION_FEATURES       = 0, // If set, uses internal instruction sequences for hw and sim test
    parameter QUICK_STARTUP             = 0, // If set, quick-launch configuration access is contained here
    parameter STATISTICS_GATHERING      = 0, // If set, I/O can be rerouted to the maint port [0,1]
    parameter C_LINK_WIDTH              = 4
    )
   //  port declarations ----------------
   (
    // Clocks and Resets
    input            sys_clkp,              // MMCM reference clock
    input            sys_clkn,              // MMCM reference clock

    input            sys_rst,               // Global reset signal

    // high-speed IO
    input           srio_rxn0,              // Serial Receive Data
    input           srio_rxp0,              // Serial Receive Data
    input           srio_rxn1,              // Serial Receive Data
    input           srio_rxp1,              // Serial Receive Data
    input            srio_rxn2,              // Serial Receive Data
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
    output  [1:0]   srio_led,

    // Data Interface

    output              clk_srio,
    output              reset_srio,
    input               self_check_in,
    output               rapidIO_ready_out,

    // NWR interface
    input               nwr_req_in,
    output              nwr_ready_out,
    output              nwr_busy_out,
    output              nwr_done_out,

    input [33:0]        user_taddr_in,
    input [63:0]        user_tdata_in,
    input               user_tvalid_in,
    input               user_tfirst_in,
    input [7:0]         user_tkeep_in,
    // data_len_in is the data actual length minuses 1
    input [15:0]        user_tlen_in,
    input               user_tlast_in,
    output              user_tready_out,
    output              ack_o
   );
   //  ----------------------------------


  // wire declarations ----------------
//
// -----------------------------------------------------------------------------
// Note : Below portion of the wire declaration should be commented when
//        used in non-shared mode AND the SRIO core 2nd instance is used to share
//        common logic like clk, rst and GT Common with another instance of SRIO
//        with Shared Logic (in DUT) option if the simulator throws errors.
// -----------------------------------------------------------------------------
    wire            log_clk;
    wire            phy_clk;
    wire            gt_pcs_clk;
    wire            log_rst;
    wire            phy_rst;
    wire            clk_lock;               // asserts from the MMCM
//

    // signals into the DUT
    wire            iotx_tvalid;
    wire            iotx_tready;
    wire            iotx_tlast;
    wire   [63:0]   iotx_tdata;
    wire   [7:0]    iotx_tkeep;
    wire   [31:0]   iotx_tuser;

    wire            iorx_tvalid;
    wire            iorx_tready;
    wire            iorx_tlast;
    wire    [63:0]  iorx_tdata;
    wire    [7:0]   iorx_tkeep;
    wire    [31:0]  iorx_tuser;

    wire            maintr_rst = 1'b0;

    wire            maintr_awvalid;
    wire            maintr_awready;
    wire   [31:0]   maintr_awaddr;
    wire            maintr_wvalid;
    wire            maintr_wready;
    wire   [31:0]   maintr_wdata;
    wire            maintr_bvalid;
    wire            maintr_bready;
    wire   [1:0]    maintr_bresp;

    wire            maintr_arvalid;
    wire            maintr_arready;
    wire   [31:0]   maintr_araddr;
    wire            maintr_rvalid;
    wire            maintr_rready;
    wire   [31:0]   maintr_rdata;
    wire   [1:0]    maintr_rresp;

    // signals from Validation modules
    wire            val_iotx_tvalid;
    wire            val_iotx_tready;
    wire            val_iotx_tlast;
    wire   [63:0]   val_iotx_tdata;
    wire   [7:0]    val_iotx_tkeep;
    wire   [31:0]   val_iotx_tuser;

    wire            val_iorx_tvalid;
    wire            val_iorx_tready;
    wire            val_iorx_tlast;
    wire    [63:0]  val_iorx_tdata;
    wire    [7:0]   val_iorx_tkeep;
    wire    [31:0]  val_iorx_tuser;

    wire            val_maintr_awvalid;
    wire            val_maintr_awready;
    wire   [31:0]   val_maintr_awaddr;
    wire            val_maintr_wvalid;
    wire            val_maintr_wready;
    wire   [31:0]   val_maintr_wdata;
    wire            val_maintr_bvalid;
    wire            val_maintr_bready;
    wire   [1:0]    val_maintr_bresp;

    wire            val_maintr_arvalid;
    wire            val_maintr_arready;
    wire   [31:0]   val_maintr_araddr;
    wire            val_maintr_rvalid;
    wire            val_maintr_rready;
    wire   [31:0]   val_maintr_rdata;
    wire   [1:0]    val_maintr_rresp;


//--
//----------------------------------------------------------------------------//

    // other core output signals that may be used by the user
    wire     [23:0] port_timeout;           // Timeout value user can use to detect a lost packet
    wire            phy_rcvd_mce;           // MCE control symbol received
    (* mark_debug = "true" *)
    wire            phy_rcvd_link_reset;    // Received 4 consecutive reset symbols
    wire            port_error;             // In Port Error State
    //(* mark_debug = "true" *)// this constraint is commented as it is failing due to new MLO flow
    wire            mode_1x;                // Link is trained down to 1x mode
    wire            srio_host;              // Endpoint is the system host
    wire    [223:0] phy_debug;              // Useful debug signals

    wire            gtrx_disperr_or;        // GT disparity error (reduce ORed)

    wire            gtrx_notintable_or;     // GT not in table error (reduce ORed)
    wire     [15:0] deviceid;               // Device ID
    wire            port_decode_error;      // No valid output port for the RX transaction
    (* mark_debug = "true" *)
    wire            idle_selected;          // The IDLE sequence has been selected
    (* mark_debug = "true" *)
    wire            idle2_selected;         // The PHY is operating in IDLE2 mode
    wire            autocheck_error;        // when set, packet didn't match expected
    (* mark_debug = "true" *)
    wire            port_initialized;       // Port is Initialized
    (* mark_debug = "true" *)
    wire            link_initialized;       // Link is Initialized
    wire            exercise_done;          // sets when the generator(s) has completed

    // other core output signals that may be used by the user
    wire            phy_mce = 1'b0;         // Send MCE control symbol
    wire            phy_link_reset = 1'b0;  // Send link reset control symbols
    wire            force_reinit = 1'b0;    // Force reinitialization


    // convert to ports when not using the pattern generator
    wire            axis_iotx_tvalid;
    wire            axis_iotx_tready;
    wire            axis_iotx_tlast;
    wire   [63:0]   axis_iotx_tdata;
    wire   [7:0]    axis_iotx_tkeep;
    wire   [31:0]   axis_iotx_tuser;

    wire            axis_iorx_tvalid;
    wire            axis_iorx_tready;
    wire            axis_iorx_tlast;
    wire    [63:0]  axis_iorx_tdata;
    wire    [7:0]   axis_iorx_tkeep;
    wire    [31:0]  axis_iorx_tuser;

    wire            axis_maintr_rst = 1'b0;
    wire            axis_maintr_awvalid = 1'b0;
    wire            axis_maintr_awready;
    wire   [31:0]   axis_maintr_awaddr = 1'b0;
    wire            axis_maintr_wvalid = 1'b0;
    wire            axis_maintr_wready;
    wire   [31:0]   axis_maintr_wdata = 1'b0;
    wire   [3:0]    axis_maintr_wstrb = 1'b0;
    wire            axis_maintr_bvalid;
    wire            axis_maintr_bready = 1'b0;
    wire   [1:0]    axis_maintr_bresp;

    wire            axis_maintr_arvalid = 1'b0;
    wire            axis_maintr_arready;
    wire   [31:0]   axis_maintr_araddr = 1'b0;
    wire            axis_maintr_rvalid;
    wire            axis_maintr_rready = 1'b0;
    wire   [31:0]   axis_maintr_rdata;
    wire   [1:0]    axis_maintr_rresp;

    wire            iotx_autocheck_error;
    wire            iotx_request_done;
    wire            maint_autocheck_error;
    wire            maint_done;

    // Vivado debug outputs for control of
    (* mark_debug = "true" *)
    wire            peek_poke_go;
    (* mark_debug = "true" *)
    wire [23:0]     user_addr;
    (* mark_debug = "true" *)
    wire  [3:0]     user_ftype;
    (* mark_debug = "true" *)
    wire  [3:0]     user_ttype;
    (* mark_debug = "true" *)
    wire  [7:0]     user_size;
    (* mark_debug = "true" *)
    wire [63:0]     user_data;
    (* mark_debug = "true" *)
    wire  [3:0]     user_hop;
    (* mark_debug = "true" *)
    wire [15:0]     dest_id;
    (* mark_debug = "true" *)
    wire [15:0]     source_id;
    (* mark_debug = "true" *)
    wire            id_override;
    (* mark_debug = "true" *)
    wire            register_reset;
    (* mark_debug = "true" *)
    wire            reset_all_registers;
    (* mark_debug = "true" *)
    wire  [3:0]     stats_address;

    wire       core_sent_pna;

    wire       core_received_pna;

    wire       core_sent_pr;

    wire       core_received_pr;

    // Debug signals
    wire            go_req   = peek_poke_go && user_ftype != 4'h8;
    wire            go_maint = peek_poke_go && user_ftype == 4'h8;
    wire            maint_inst = user_ttype == 4'h0;
    reg   [63:0]    captured_data;
    (* mark_debug = "true" *)
    wire            continuous_go;
    reg             continuous_go_q;
    reg             iotx_autocheck_error_q;
    reg             iotx_request_done_q;
    reg             reset_request_gen;
    (* mark_debug = "true" *)
    reg             continuous_in_process;
    reg             reset_continuous_set;
    (* mark_debug = "true" *)
    reg             stop_continuous_test;
    reg   [15:0]    reset_continuous_srl;
    wire  [31:0]    stats_data;
  // }}} End wire declarations ------------
//Added by Chunjie
  //wire sys_rst;

   wire [15:0] src_id = 16'h01;
  wire [15:0] des_id = 16'hf0;

  wire              rapidIO_ready;
  reg [2:0]         nwr_done_r;
  // Count the times of NWR operation
  reg [3:0]         nwr_cnt;
  reg               nwr_req_p;
  reg               nwr_ready_r0, nwr_ready_r1;
  reg               nwr_req_en, nwr_req_en_r;
  wire [0:0]        nwr_req;


  wire              user_ready;
  wire              user_tready;
  wire [7:0]       user_tsize;

  wire [63:0]       user_tdata;
  wire              user_tvalid;
  wire [7:0]        user_tkeep;
  wire              user_tlast;

  reg [12:0]        initialized_cnt;
  reg               initialized_delay_r;
  wire              initialized_delay;

  wire [1:0]        ed_ready = 2'd1;

  // enable pulse
  reg               db_self_check_en, db_self_check_r;
  wire [0:0]        db_self_check;

  // Debug signals
  wire [0:0]        mode_1x_vio;
  wire [0:0]        port_initialized_vio;
  wire [0:0]        link_initialized_vio;
  wire [0:0]        clk_lock_vio;
  wire [0:0]        port_error_vio;

  wire [0:0]        nwr_ready_ila;
  wire [0:0]        nwr_busy_ila;

  wire [0:0]        nwr_done_ila;
  wire [0:0]        link_initialized_ila;
  wire [0:0]        user_tready_ila;
  wire [0:0]        iotx_tvalid_ila;
  wire [0:0]        iotx_tlast_ila;

  wire              sim_train_en = 1'b0;
  //assign sys_rst = ~sys_rst_n;

assign srio_led[0] = !mode_1x;
assign srio_led[1] = ~link_initialized;


  // {{{ Drive LEDs to Development Board -------
/*    assign led0[0] = 1'b1;
    assign led0[1] = 1'b1;
    assign led0[2] = !mode_1x;
    assign led0[3] = port_initialized;
    assign led0[4] = link_initialized;
    assign led0[5] = clk_lock;
    assign led0[6] = sim_train_en ? autocheck_error : 1'b0;
    assign led0[7] = sim_train_en ? exercise_done : 1'b0;
    */
  // }}} End LEDs to Development Board ---------

    // assign send_pna               = phy_debug[0];
    // assign sent_pna_cause_lsb     = phy_debug[34:32];
    // assign in_recoverable_detect  = phy_debug[40];
    // assign in_retry_detect        = phy_debug[39];
    // assign out_recoverable_detect = phy_debug[38];
    // assign out_fatal_detect       = phy_debug[37];
    // assign send_pna               = phy_debug[0];
    assign core_sent_pna     = phy_debug[160];
    assign core_received_pna = phy_debug[161];
    assign core_sent_pr      = phy_debug[162];
    assign core_received_pr  = phy_debug[163];




      assign continuous_go        = 1'b0;
      assign peek_poke_go         = 1'b0;
      assign user_addr            = 24'b0;
      assign user_ftype           = 4'b0;
      assign user_ttype           = 4'b0;
      assign user_size            = 8'b0;
      assign user_data            = 64'b0;
      assign user_hop             = 4'b0;
      assign dest_id              = 16'b0;
      assign source_id            = 16'b0;
      assign id_override          = 1'b0;
      assign register_reset       = 1'b0;
      assign reset_all_registers  = 1'b0;
      assign stats_address        = 4'b0;

/*
       // control Si53301
   assign si53301_OEA = 1'bz;
   assign si53301_OEB = 1'bz;
   assign si53301_CLKSEL = 1'b0;
   assign fsp_disable = 3'b000;
*/
  assign mode_1x_vio[0] = mode_1x;
  assign port_initialized_vio[0] = port_initialized;
  assign link_initialized_vio[0] = link_initialized;
  assign clk_lock_vio[0] = clk_lock;
  assign port_error_vio[0] = port_error;

  assign nwr_ready_ila[0] = nwr_ready_out;
  assign nwr_busy_ila[0] = nwr_busy_out;
  assign nwr_done_ila[0] = nwr_done_out;
  assign link_initialized_ila[0] = link_initialized;
  assign user_tready_ila[0] = user_tready;
  assign iotx_tvalid_ila[0] = iotx_tvalid;
  assign iotx_tlast_ila[0] = iotx_tlast;

   // Generate doorbell self-check enable and nwr request enable by VIO
   `ifndef SIM
       always @(posedge log_clk) begin
        if (log_rst) begin
            db_self_check_en <= 1'b0;
            db_self_check_r <= 1'b0;
            nwr_req_en <= 1'b0;
            nwr_req_en_r <= 1'b0;
        end
    else begin
        db_self_check_r <= db_self_check[0];
        db_self_check_en <= !db_self_check_r & db_self_check[0];
        nwr_req_en_r <= nwr_req[0];
        nwr_req_en <= !nwr_req_en_r & nwr_req[0] ;
        end
    end
    `endif

    // Used only in simulation to generate doorbell request
    `ifdef SIM
    always @(posedge log_clk) begin
        if (log_rst) begin
            initialized_cnt <= 'h0;
        end
        else if (link_initialized && ~initialized_delay) begin
            initialized_cnt <= initialized_cnt + 'h1;
        end
        else if (!link_initialized) begin
            initialized_cnt <= 'h0;
        end
    end

    assign initialized_delay = initialized_cnt[5];

    // Generate doorbell self-check enable pulse
    always @(posedge log_clk) begin
        if (log_rst) begin
            initialized_delay_r <= 1'b0;
            nwr_done_r <= 'h0;
        end
        else begin
            initialized_delay_r <= initialized_delay;
            nwr_done_r[2:0] <= {nwr_done_r[1:0], nwr_done};
            db_self_check_en <= (~initialized_delay_r & initialized_delay) || nwr_done_r[2];

        end
    end

    always @(posedge log_clk) begin
        if (log_rst) begin
            nwr_cnt <= 'h0;
        end
        else begin
            if (nwr_cnt == 'd8) begin
                $stop;
            end
            else if (nwr_done_r[2]) begin
                nwr_cnt <= nwr_cnt + 'h1;
            end
        end
    end


    // Generate NWR enable pulse
    always @(posedge log_clk) begin
        if (log_rst) begin
            nwr_ready_r0 <= 1'b0;
            nwr_ready_r1 <= 1'b1;
            nwr_req_en <= 1'b0;
        end
        else begin
            nwr_ready_r0 <= nwr_ready;
            nwr_ready_r1 <= nwr_ready_r0;
            nwr_req_en <= (~nwr_ready_r1 & nwr_ready_r0);
        end
    end

    `endif

    generate if (!VALIDATION_FEATURES && !MIRROR) begin: db_req_gen

    assign clk_srio = log_clk;
    assign reset_srio = log_rst;

    input_reader input_reader_i
    (
        .clk             (log_clk),
        .reset           (log_rst),

        .data_in         (user_tdata_in),
        .data_valid_in   (user_tvalid_in),
        .data_first_in   (user_tfirst_in),
        .data_keep_in    (user_tkeep_in),
        .data_len_in     (user_tlen_in),
        .data_last_in    (user_tlast_in),
        .data_ready_out  (user_tready_out),
        .ack_o           (ack_o),

        .output_tready_in(user_tready),
        .output_tdata    (user_tdata),
        .output_tvalid   (user_tvalid),
        .output_tkeep    (user_tkeep),
        .output_data_len (user_tsize),
        .output_tlast    (user_tlast),
        .output_tfirst   (user_tfirst),
        .output_done     ()

        );

    db_req
    #(.SIM(SIM_1))
    db_req_i

        (
        .log_clk(log_clk),
        .log_rst(log_rst),

        .src_id(src_id),
        .des_id(des_id),

        .self_check_in(db_self_check_en),
        .nwr_req_in(nwr_req_in),
        .rapidIO_ready_o(rapidIO_ready_out),
        .link_initialized(link_initialized),

        .nwr_ready_o(nwr_ready_out),
        .nwr_busy_o(nwr_busy_out),
        .nwr_done_ack_o(nwr_done_out),

        .user_tready_o(user_tready),
        .user_addr(user_taddr_in),
        .user_tsize_in(user_tsize),
        .user_tdata_in(user_tdata),
        .user_tvalid_in(user_tvalid),
        .user_tfirst_in(user_tfirst),
        .user_tkeep_in(user_tkeep),
        .user_tlast_in(user_tlast),

        .error_out(),
        .error_type_o(),
        .error_target_id(),

        .ireq_tvalid_o(iotx_tvalid),
        .ireq_tready_in(iotx_tready),
        .ireq_tlast_o(iotx_tlast),
        .ireq_tdata_o(iotx_tdata),
        .ireq_tkeep_o(iotx_tkeep),
        .ireq_tuser_o(iotx_tuser),

        .iresp_tvalid_in(iorx_tvalid),
        .iresp_tready_o(iorx_tready),
        .iresp_tlast_in(iorx_tlast),
        .iresp_tdata_in(iorx_tdata),
        .iresp_tkeep_in(iorx_tkeep),
        .iresp_tuser_in(iorx_tuser)
        );
/*
    user_logic user_logic_i
    (
        .log_clk(log_clk),
        .log_rst(log_rst),

        .nwr_ready_in(nwr_ready),
        .nwr_busy_in(nwr_busy),
        .nwr_done_in(nwr_done),

        .user_tready_in(user_tready),
        .user_addr_o(user_taddr),
        .user_tsize_o(user_tsize),
        .user_tdata_o(user_tdata),
        .user_tvalid_o(user_tvalid),
        .user_tkeep_o(user_tkeep),
        .user_tlast_o(user_tlast)

    );
    */
    end
    endgenerate

    //generate if (!VALIDATION_FEATURES) begin: db_resp_gen
    generate if (!VALIDATION_FEATURES && MIRROR) begin: db_resp_gen
    // db_resp is used to simulate the bahavor of target, when synthesize, comment it.
    db_resp
    #(.SIM(SIM_1))
    db_resp_i (
      .log_clk(log_clk),
      .log_rst(log_rst),

      .src_id(16'hf0),
      .des_id(16'hb0),

      .ed_ready_in(ed_ready),

      .treq_tvalid_in(iorx_tvalid),
      .treq_tready_o(iorx_tready),
      .treq_tlast_in(iorx_tlast),
      .treq_tdata_in(iorx_tdata),
      .treq_tkeep_in(iorx_tkeep),
      .treq_tuser_in(iorx_tuser),

      // response interface
      .tresp_tready_in(iotx_tready),
      .tresp_tvalid_o(iotx_tvalid),
      .tresp_tlast_o(iotx_tlast),
      .tresp_tdata_o(iotx_tdata),
      .tresp_tkeep_o(iotx_tkeep),
      .tresp_tuser_o(iotx_tuser)
      );


    end
endgenerate
//end
    `ifndef SIM
    vio_srio vio_srio_i (
    .clk(log_clk),                // input wire clk
    .probe_in0(mode_1x_vio),    // input wire [0 : 0] probe_in0
    .probe_in1(port_initialized_vio),    // input wire [0 : 0] probe_in1
    .probe_in2(link_initialized_vio),    // input wire [0 : 0] probe_in2
    .probe_in3(clk_lock_vio),    // input wire [0 : 0] probe_in3
    .probe_out0(db_self_check),  // output wire [0 : 0] probe_out0
    .probe_out1(nwr_req)  // output wire [0 : 0] probe_out1
);

    ila_nwr ila_nwr_i (
        .clk(log_clk), // input wire clk
        .probe0(nwr_ready_ila), // input wire [0:0]  probe0
        .probe1(nwr_busy_ila), // input wire [0:0]  probe1
        .probe2(nwr_done_ila), // input wire [0:0]  probe2
        .probe3(link_initialized_ila), // input wire [0:0]  probe3
        .probe4(user_tready_ila), // input wire [0:0]  probe4
        .probe5(iotx_tvalid_ila), // input wire [0:0]  probe5
        .probe6(iotx_tlast_ila), // input wire [0:0]  probe6
        .probe7(iotx_tuser), // input wire [31:0]  probe7
        .probe8(iotx_tdata), // input wire [63:0]  probe8
        .probe9(iotx_tkeep) // input wire [7:0]  probe9
    );
    `endif




  // SRIO_DUT instantation -----------------
  // for production and shared logic in the core
  srio_gen2_lane4  srio_gen2_0_inst
     (//---------------------------------------------------------------
      .sys_clkp                (sys_clkp  ),
      .sys_clkn                (sys_clkn  ),
      .sys_rst                 (sys_rst   ),
      // all clocks as output in shared logic mode
      .log_clk_out             (log_clk   ),
      .phy_clk_out             (phy_clk   ),
      .gt_clk_out              (gt_clk    ),
      .gt_pcs_clk_out          (gt_pcs_clk),

      .drpclk_out              (drpclk    ),

      .refclk_out              (refclk    ),

      .clk_lock_out            (clk_lock  ),
      // all resets as output in shared logic mode
      .log_rst_out             (log_rst   ),
      .phy_rst_out             (phy_rst   ),
      .buf_rst_out             (buf_rst   ),
      .cfg_rst_out             (cfg_rst   ),
      .gt_pcs_rst_out          (gt_pcs_rst),

//---------------------------------------------------------------
      .gt0_qpll_clk_out        (gt0_qpll_clk_out        ),
      .gt0_qpll_out_refclk_out (gt0_qpll_out_refclk_out ),




// //---------------------------------------------------------------
      .srio_rxn0                    (srio_rxn0),
      .srio_rxp0                    (srio_rxp0),
      .srio_rxn1                    (srio_rxn1),
      .srio_rxp1                    (srio_rxp1),
      .srio_rxn2                    (srio_rxn2),
      .srio_rxp2                    (srio_rxp2),
      .srio_rxn3                    (srio_rxn3),
      .srio_rxp3                    (srio_rxp3),

      .srio_txn0                    (srio_txn0),
      .srio_txp0                    (srio_txp0),
      .srio_txn1                    (srio_txn1),
      .srio_txp1                    (srio_txp1),
      .srio_txn2                    (srio_txn2),
      .srio_txp2                    (srio_txp2),
      .srio_txn3                    (srio_txn3),
      .srio_txp3                    (srio_txp3),

      .s_axis_iotx_tvalid            (iotx_tvalid),
      .s_axis_iotx_tready            (iotx_tready),
      .s_axis_iotx_tlast             (iotx_tlast),
      .s_axis_iotx_tdata             (iotx_tdata),
      .s_axis_iotx_tkeep             (iotx_tkeep),
      .s_axis_iotx_tuser             (iotx_tuser),

      .m_axis_iorx_tvalid            (iorx_tvalid),
      .m_axis_iorx_tready            (iorx_tready),
      .m_axis_iorx_tlast             (iorx_tlast),
      .m_axis_iorx_tdata             (iorx_tdata),
      .m_axis_iorx_tkeep             (iorx_tkeep),
      .m_axis_iorx_tuser             (iorx_tuser),

      .s_axi_maintr_rst              (maintr_rst),

      .s_axi_maintr_awvalid          (maintr_awvalid),
      .s_axi_maintr_awready          (maintr_awready),
      .s_axi_maintr_awaddr           (maintr_awaddr),
      .s_axi_maintr_wvalid           (maintr_wvalid),
      .s_axi_maintr_wready           (maintr_wready),
      .s_axi_maintr_wdata            (maintr_wdata),
      .s_axi_maintr_bvalid           (maintr_bvalid),
      .s_axi_maintr_bready           (maintr_bready),
      .s_axi_maintr_bresp            (maintr_bresp),

      .s_axi_maintr_arvalid          (maintr_arvalid),
      .s_axi_maintr_arready          (maintr_arready),
      .s_axi_maintr_araddr           (maintr_araddr),
      .s_axi_maintr_rvalid           (maintr_rvalid),
      .s_axi_maintr_rready           (maintr_rready),
      .s_axi_maintr_rdata            (maintr_rdata),
      .s_axi_maintr_rresp            (maintr_rresp),

      .sim_train_en                  (sim_train_en),
      .phy_mce                       (phy_mce),
      .phy_link_reset                (phy_link_reset),
      .force_reinit                  (force_reinit),


      .phy_rcvd_mce                  (phy_rcvd_mce       ),
      .phy_rcvd_link_reset           (phy_rcvd_link_reset),
      .phy_debug                     (phy_debug          ),
      .gtrx_disperr_or               (gtrx_disperr_or    ),
      .gtrx_notintable_or            (gtrx_notintable_or ),

      .port_error                    (port_error         ),
      .port_timeout                  (port_timeout       ),
      .srio_host                     (srio_host          ),
      .port_decode_error             (port_decode_error  ),
      .deviceid                      (deviceid           ),
      .idle2_selected                (idle2_selected     ),
      .phy_lcl_master_enable_out     (), // these are side band output only signals
      .buf_lcl_response_only_out     (),
      .buf_lcl_tx_flow_control_out   (),
      .buf_lcl_phy_buf_stat_out      (),
      .phy_lcl_phy_next_fm_out       (),
      .phy_lcl_phy_last_ack_out      (),
      .phy_lcl_phy_rewind_out        (),
      .phy_lcl_phy_rcvd_buf_stat_out (),
      .phy_lcl_maint_only_out        (),
      .port_initialized              (port_initialized  ),
      .link_initialized              (link_initialized  ),
      .idle_selected                 (idle_selected     ),
      .mode_1x                       (mode_1x           )
     );
  // End of SRIO_DUT instantiation ---------


  // Initiator-driven side --------------------






  assign autocheck_error         = iotx_autocheck_error || maint_autocheck_error;
  assign exercise_done           = iotx_request_done && maint_done;

  // }}} End of Initiator-driven side -------------




  // {{{ Maintenance Interface --------------------

  // Select between internally-driven sequences or user sequences
  assign maintr_awvalid = (QUICK_STARTUP) ? val_maintr_awvalid : axis_maintr_awvalid;
  assign maintr_awaddr  = (QUICK_STARTUP) ? val_maintr_awaddr  : axis_maintr_awaddr;
  assign maintr_wvalid  = (QUICK_STARTUP) ? val_maintr_wvalid  : axis_maintr_wvalid;
  assign maintr_wdata   = (QUICK_STARTUP) ? val_maintr_wdata   : axis_maintr_wdata;
  assign maintr_bready  = (QUICK_STARTUP) ? val_maintr_bready  : axis_maintr_bready;

  assign maintr_arvalid = (QUICK_STARTUP) ? val_maintr_arvalid : axis_maintr_arvalid;
  assign maintr_araddr  = (QUICK_STARTUP) ? val_maintr_araddr  : axis_maintr_araddr;
  assign maintr_rready  = (QUICK_STARTUP) ? val_maintr_rready  : axis_maintr_rready;


  assign axis_maintr_awready = (!QUICK_STARTUP) && maintr_awready;
  assign axis_maintr_wready = (!QUICK_STARTUP) && maintr_wready;
  assign axis_maintr_bvalid = (!QUICK_STARTUP) && maintr_bvalid;
  assign axis_maintr_bresp = maintr_bresp;

  assign axis_maintr_arready = (!QUICK_STARTUP) && maintr_arready;
  assign axis_maintr_rvalid = (!QUICK_STARTUP) && maintr_rvalid;
  assign axis_maintr_rdata = maintr_rdata;
  assign axis_maintr_rresp = maintr_rresp;

  assign val_maintr_awready = (QUICK_STARTUP) && maintr_awready;
  assign val_maintr_wready = (QUICK_STARTUP) && maintr_wready;
  assign val_maintr_bvalid = (QUICK_STARTUP) && maintr_bvalid;
  assign val_maintr_bresp = maintr_bresp;

  assign val_maintr_arready = (QUICK_STARTUP) && maintr_arready;
  assign val_maintr_rvalid = (QUICK_STARTUP) && maintr_rvalid;
  assign val_maintr_rdata = maintr_rdata;
  assign val_maintr_rresp = maintr_rresp;

/*
  // If internally-driven sequences are required
  generate if (QUICK_STARTUP) begin: quick_maint_gen
   srio_quick_start_srio_gen2_0 srio_quick_start_inst (
      .log_clk                 (log_clk),
      .log_rst                 (log_rst),

      .maintr_awvalid          (val_maintr_awvalid),
      .maintr_awready          (val_maintr_awready),
      .maintr_awaddr           (val_maintr_awaddr),
      .maintr_wvalid           (val_maintr_wvalid),
      .maintr_wready           (val_maintr_wready),
      .maintr_wdata            (val_maintr_wdata),
      .maintr_bvalid           (val_maintr_bvalid),
      .maintr_bready           (val_maintr_bready),
      .maintr_bresp            (val_maintr_bresp),

      .maintr_arvalid          (val_maintr_arvalid),
      .maintr_arready          (val_maintr_arready),
      .maintr_araddr           (val_maintr_araddr),
      .maintr_rvalid           (val_maintr_rvalid),
      .maintr_rready           (val_maintr_rready),
      .maintr_rdata            (val_maintr_rdata),
      .maintr_rresp            (val_maintr_rresp),

      // use these ports to peek/poke maintenance transactions
      .go                      (go_maint),
      .user_hop                (user_hop),
      .user_inst               (maint_inst),
      .user_addr               (user_addr),
      .user_data               (user_data[31:0]),

      .link_initialized        (link_initialized),
      .maint_done              (maint_done),
      .maint_autocheck_error   (maint_autocheck_error)
     );
  end else begin : no_quick_maint_gen
    assign maintr_awaddr         = 32'h0;
    assign maintr_wvalid         = 1'b0;
    assign maintr_wdata          = 32'h0;
    assign maintr_bready         = 1'b0;
    assign maintr_arvalid        = 1'b0;
    assign maintr_araddr         = 32'h0;
    assign maintr_rready         = 1'b0;
    assign maint_done            = 1'b1;
    assign maint_autocheck_error = 1'b0;
  end
  endgenerate

  // }}} End of Maintenance Interface -------------
*/




  // }}} End of Statistics Gatherer ---------------

endmodule
