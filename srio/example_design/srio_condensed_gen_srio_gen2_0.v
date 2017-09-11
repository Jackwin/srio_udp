//-----------------------------------------------------------------------------
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
// 	PART OF THIS FILE AT ALL TIMES.                                
//-----------------------------------------------------------------------------
//
// File name:    srio_condensed_gen.v
// Rev:          1.1
// Description:
// This module wraps around the request and response generator
// in condensed IO mode
//
// Hierarchy:
// SRIO_EXAMPLE_TOP
//   |____> SRIO_DUT
//     |____> SRIO_WRAPPER
//     |____> SRIO_CLK
//     |____> SRIO_RST
//   |____> SRIO_STATISTICS
//   |____> SRIO_REPORT
//   |____> SRIO_CONDENSED_GEN
//     |____> SRIO_REQUEST_GEN
//     |____> SRIO_RESPONSE_GEN
//   |____> SRIO_QUICK_START
//
//-----------------------------------------------------------------------------
`timescale 1ps/1ps

module srio_condensed_gen_srio_gen2_0
   (
    input             log_clk,
    input             log_rst,

    input      [15:0] deviceid,
    input      [15:0] dest_id,
    input      [15:0] source_id,
    input             id_override,

    output            val_iotx_tvalid,
    input             val_iotx_tready,
    output            val_iotx_tlast,
    output     [63:0] val_iotx_tdata,
    output      [7:0] val_iotx_tkeep,
    output     [31:0] val_iotx_tuser,

    input             val_iorx_tvalid,
    output            val_iorx_tready,
    input             val_iorx_tlast,
    input      [63:0] val_iorx_tdata,
    input       [7:0] val_iorx_tkeep,
    input      [31:0] val_iorx_tuser,

    input             link_initialized,
    input             go,
    input      [33:0] user_addr,
    input       [3:0] user_ftype,
    input       [3:0] user_ttype,
    input       [7:0] user_size,
    input      [63:0] user_data,

    output            request_autocheck_error,
    output            request_done
   );

  // {{{ local parameters -----------------
  localparam       TARGET    = 1'b1;
  localparam       INITIATOR = 1'b0;

  localparam [3:0] RESP      = 4'hD;
  // }}} End local parameters -------------


  // {{{ wire declarations ----------------
  wire            val_ireq_tvalid;
  wire            val_ireq_tready;
  wire            val_ireq_tlast;
  wire   [63:0]   val_ireq_tdata;
  wire   [7:0]    val_ireq_tkeep;
  wire   [31:0]   val_ireq_tuser;

  wire            val_iresp_tvalid;
  wire            val_iresp_tready;
  wire            val_iresp_tlast;
  wire    [63:0]  val_iresp_tdata;
  wire    [7:0]   val_iresp_tkeep;
  wire    [31:0]  val_iresp_tuser;

  wire            val_treq_tvalid;
  wire            val_treq_tready;
  wire            val_treq_tlast;
  wire    [63:0]  val_treq_tdata;
  wire    [7:0]   val_treq_tkeep;
  wire    [31:0]  val_treq_tuser;

  wire            val_tresp_tvalid;
  wire            val_tresp_tready;
  wire            val_tresp_tlast;
  wire   [63:0]   val_tresp_tdata;
  wire   [7:0]    val_tresp_tkeep;
  wire   [31:0]   val_tresp_tuser;

  // Receive path pipeline
  reg   [104:0]   pipeline_in_stg1 = 0;
  reg   [104:0]   pipeline_in_stg2 = 0;
  reg   [104:0]   pipeline_in_stg3 = 0;
  reg             pipeline_vld_stg1;
  reg             pipeline_vld_stg2;
  reg             pipeline_vld_stg3;
  reg     [1:0]   pipeline_in_select;

  reg             iorx_port_select, iorx_port_select_q;
  reg             iotx_port_select, iotx_port_select_q;
  reg             rx_out_of_packet, tx_out_of_packet;
  // }}} End wire declarations ------------


  // {{{ Receive Path Pipeline ------------
  always @(posedge log_clk) begin
    if (val_iorx_tvalid && val_iorx_tready) begin
      pipeline_in_stg1 <= {val_iorx_tlast, val_iorx_tkeep, val_iorx_tuser, val_iorx_tdata};
    end
    if ((!pipeline_vld_stg2 || !pipeline_vld_stg3) ||
        ((val_iresp_tvalid && val_iresp_tready) || (val_treq_tvalid && val_treq_tready))) begin
      pipeline_in_stg2 <= pipeline_in_stg1;
    end
    if ((!pipeline_vld_stg3) ||
        ((val_iresp_tvalid && val_iresp_tready) || (val_treq_tvalid && val_treq_tready))) begin
      pipeline_in_stg3 <= pipeline_in_stg2;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      pipeline_vld_stg1 <= 1'b0;
    end else if (val_iorx_tvalid && val_iorx_tready) begin
      pipeline_vld_stg1 <= 1'b1;
    end else if (!pipeline_vld_stg2 || !pipeline_vld_stg3) begin
      pipeline_vld_stg1 <= 1'b0;
    end else if ((val_iresp_tvalid && val_iresp_tready) || (val_treq_tvalid && val_treq_tready)) begin
      pipeline_vld_stg1 <= 1'b0;
    end
    if (log_rst) begin
      pipeline_vld_stg2 <= 1'b0;
    end else if (pipeline_vld_stg1) begin
      pipeline_vld_stg2 <= !((pipeline_in_select == 2'b01) &&
                             ((val_iresp_tvalid && val_iresp_tready) || (val_treq_tvalid && val_treq_tready)));
    end else if (!pipeline_vld_stg3 ||
                 (pipeline_in_select == 2'b11 || pipeline_in_select == 2'b10) &&
                  ((val_iresp_tvalid && val_iresp_tready) || (val_treq_tvalid && val_treq_tready))) begin
      pipeline_vld_stg2 <= 1'b0;
    end
    if (log_rst) begin
      pipeline_vld_stg3 <= 1'b0;
    end else if (pipeline_vld_stg2) begin
      pipeline_vld_stg3 <= !((pipeline_in_select == 2'b10) &&
                             ((val_iresp_tvalid && val_iresp_tready) || (val_treq_tvalid && val_treq_tready)));
    end else if (pipeline_in_select == 2'b11 &&
                  ((val_iresp_tvalid && val_iresp_tready) || (val_treq_tvalid && val_treq_tready))) begin
      pipeline_vld_stg3 <= 1'b0;
    end
  end
  always @* begin
    casex ({pipeline_vld_stg3, pipeline_vld_stg2, pipeline_vld_stg1})
      3'b1xx  : pipeline_in_select = 2'b11;
      3'b01x  : pipeline_in_select = 2'b10;
      3'b001  : pipeline_in_select = 2'b01;
      default : pipeline_in_select = 2'b00;
    endcase
  end
  // }}} End Receive Path Pipeline --------


  // {{{ mux logic ------------------------
  always @(posedge log_clk) begin
    if (log_rst) begin
      tx_out_of_packet <= 1'b1;
    end else if (val_iotx_tvalid && val_iotx_tready && val_iotx_tlast) begin
      tx_out_of_packet <= 1'b1;
    end else if (val_iotx_tvalid && val_iotx_tready) begin
      tx_out_of_packet <= 1'b0;
    end
  end
  always @* begin
    if (tx_out_of_packet) begin
      if (val_tresp_tvalid) begin
        iotx_port_select = TARGET;
      end else begin
        iotx_port_select = INITIATOR;
      end
    end else begin
      iotx_port_select = iotx_port_select_q;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      iotx_port_select_q <= INITIATOR;
    end else begin
      iotx_port_select_q <= iotx_port_select;
    end
  end


  always @(posedge log_clk) begin
    if (log_rst) begin
      rx_out_of_packet <= 1'b1;

    end else if ((val_iresp_tvalid && val_iresp_tready && val_iresp_tlast) ||
                 (val_treq_tvalid && val_treq_tready && val_treq_tlast)) begin
      rx_out_of_packet <= 1'b1;
    end else if ((val_iresp_tvalid && val_iresp_tready) ||
                 (val_treq_tvalid && val_treq_tready)) begin
      rx_out_of_packet <= 1'b0;
    end
  end
  always @* begin
    if (rx_out_of_packet) begin
      if (pipeline_vld_stg3) begin
        if (pipeline_in_stg3[55:52] == RESP) begin
          iorx_port_select = INITIATOR;
        end else begin
          iorx_port_select = TARGET;
        end
      end else if (pipeline_vld_stg2) begin
        if (pipeline_in_stg2[55:52] == RESP) begin
          iorx_port_select = INITIATOR;
        end else begin
          iorx_port_select = TARGET;
        end
      end else if (pipeline_vld_stg1) begin
        if (pipeline_in_stg1[55:52] == RESP) begin
          iorx_port_select = INITIATOR;
        end else begin
          iorx_port_select = TARGET;
        end
      end else begin
        iorx_port_select = iorx_port_select_q;
      end
    end else begin
      iorx_port_select = iorx_port_select_q;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      iorx_port_select_q <= INITIATOR;
    end else begin
      iorx_port_select_q <= iorx_port_select;
    end
  end
  // }}} End mux logic --------------------


  // {{{ routing assignments --------------

  // IOTX
  assign val_ireq_tready  = iotx_port_select != TARGET && val_iotx_tready;
  assign val_tresp_tready = iotx_port_select == TARGET && val_iotx_tready;

  assign val_iotx_tvalid  = iotx_port_select == TARGET ? val_tresp_tvalid : val_ireq_tvalid;
  assign val_iotx_tlast   = iotx_port_select == TARGET ? val_tresp_tlast  : val_ireq_tlast;
  assign val_iotx_tdata   = iotx_port_select == TARGET ? val_tresp_tdata  : val_ireq_tdata;
  assign val_iotx_tkeep   = iotx_port_select == TARGET ? val_tresp_tkeep  : val_ireq_tkeep;
  assign val_iotx_tuser   = iotx_port_select == TARGET ? val_tresp_tuser  : val_ireq_tuser;

  // IORX
  assign val_iresp_tvalid = iorx_port_select != TARGET && (pipeline_vld_stg3 || pipeline_vld_stg2 || pipeline_vld_stg1);
  assign val_iresp_tlast  = pipeline_in_select == 2'b11 ? pipeline_in_stg3[104] : 
                            pipeline_in_select == 2'b10 ? pipeline_in_stg2[104] : pipeline_in_stg1[104];
  assign val_iresp_tdata  = pipeline_in_select == 2'b11 ? pipeline_in_stg3[63:0] : 
                            pipeline_in_select == 2'b10 ? pipeline_in_stg2[63:0] : pipeline_in_stg1[63:0];
  assign val_iresp_tkeep  = pipeline_in_select == 2'b11 ? pipeline_in_stg3[103:96] :
                            pipeline_in_select == 2'b10 ? pipeline_in_stg2[103:96] : pipeline_in_stg1[103:96];
  assign val_iresp_tuser  = pipeline_in_select == 2'b11 ? pipeline_in_stg3[95:64] :
                            pipeline_in_select == 2'b10 ? pipeline_in_stg2[95:64] : pipeline_in_stg1[95:64];

  assign val_treq_tvalid  = iorx_port_select == TARGET && (pipeline_vld_stg3 || pipeline_vld_stg2 || pipeline_vld_stg1);
  assign val_treq_tlast   = pipeline_in_select == 2'b11 ? pipeline_in_stg3[104] : 
                            pipeline_in_select == 2'b10 ? pipeline_in_stg2[104] : pipeline_in_stg1[104];
  assign val_treq_tdata   = pipeline_in_select == 2'b11 ? pipeline_in_stg3[63:0] : 
                            pipeline_in_select == 2'b10 ? pipeline_in_stg2[63:0] : pipeline_in_stg1[63:0];
  assign val_treq_tkeep   = pipeline_in_select == 2'b11 ? pipeline_in_stg3[103:96] :
                            pipeline_in_select == 2'b10 ? pipeline_in_stg2[103:96] : pipeline_in_stg1[103:96];
  assign val_treq_tuser   = pipeline_in_select == 2'b11 ? pipeline_in_stg3[95:64] :
                            pipeline_in_select == 2'b10 ? pipeline_in_stg2[95:64] : pipeline_in_stg1[95:64];

  assign val_iorx_tready  = !(pipeline_vld_stg3 && pipeline_vld_stg2 && pipeline_vld_stg1);
  // }}} End routing assignments ----------


  // {{{ Initiator Generator/Checker --------------

  // If internally-driven sequences are required
   srio_request_gen_srio_gen2_0
     #(.SEND_SWRITE       (1),
       .SEND_NWRITER      (1),
       .SEND_NWRITE       (1),
       .SEND_NREAD        (1),
       .SEND_DB           (1),
       .SEND_MSG          (1))
     srio_request_gen_inst (
      .log_clk                 (log_clk),
      .log_rst                 (log_rst),

      .deviceid                (deviceid),
      .dest_id                 (dest_id),
      .source_id               (source_id),
      .id_override             (id_override),

      .val_ireq_tvalid         (val_ireq_tvalid),
      .val_ireq_tready         (val_ireq_tready),
      .val_ireq_tlast          (val_ireq_tlast),
      .val_ireq_tdata          (val_ireq_tdata),
      .val_ireq_tkeep          (val_ireq_tkeep),
      .val_ireq_tuser          (val_ireq_tuser),

      .val_iresp_tvalid        (val_iresp_tvalid),
      .val_iresp_tready        (val_iresp_tready),
      .val_iresp_tlast         (val_iresp_tlast),
      .val_iresp_tdata         (val_iresp_tdata),
      .val_iresp_tkeep         (val_iresp_tkeep),
      .val_iresp_tuser         (val_iresp_tuser),

      .go                      (go),
      .user_addr               (user_addr),
      .user_ftype              (user_ftype),
      .user_ttype              (user_ttype),
      .user_size               (user_size),
      .user_data               (user_data),

      .link_initialized        (link_initialized),
      .request_autocheck_error (request_autocheck_error),
      .request_done            (request_done)
     );
  // }}} End of Initiator Generator/Checker -------


  // {{{ Target Generator/Checker -----------------

  // If internally-driven sequences are required
   srio_response_gen_srio_gen2_0 srio_response_gen_inst (
      .log_clk                 (log_clk),
      .log_rst                 (log_rst),

      .deviceid                (deviceid),
      .source_id               (source_id),
      .id_override             (id_override),

      .val_tresp_tvalid        (val_tresp_tvalid),
      .val_tresp_tready        (val_tresp_tready),
      .val_tresp_tlast         (val_tresp_tlast),
      .val_tresp_tdata         (val_tresp_tdata),
      .val_tresp_tkeep         (val_tresp_tkeep),
      .val_tresp_tuser         (val_tresp_tuser),

      .val_treq_tvalid         (val_treq_tvalid),
      .val_treq_tready         (val_treq_tready),
      .val_treq_tlast          (val_treq_tlast),
      .val_treq_tdata          (val_treq_tdata),
      .val_treq_tkeep          (val_treq_tkeep),
      .val_treq_tuser          (val_treq_tuser)
     );
  // }}} End of Target Generator/Checker ----------


endmodule
