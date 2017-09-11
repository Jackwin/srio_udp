//----------------------------------------------------------------------
//
// SRIO_STATISTICS
// Description:
// This module collects statistical information about interface
// upon which it is sitting
//
// Hierarchy:
// SRIO_EXAMPLE_TOP
//   |____> SRIO_DUT
//   |____> SRIO_STATISTICS
//   |____> SRIO_REPORT
//   |____> SRIO_REQUEST_GEN
//   |____> SRIO_RESPONSE_GEN
//   |____> SRIO_QUICK_START
//
// ---------------------------------------------------------------------

`timescale 1ps/1ps

module srio_statistics_srio_gen2_0
 (
  input             log_clk,
  input             phy_clk,
  input             gt_pcs_clk,
  input             log_rst,
  input             phy_rst,

  // outgoing port 1
  input             tvalid_o1,
  input             tready_o1,
  input             tlast_o1,
  input      [63:0] tdata_o1,

  // outgoing port 2
  input             tvalid_o2,
  input             tready_o2,
  input             tlast_o2,
  input      [63:0] tdata_o2,

  // incoming port 1
  input             tvalid_i1,
  input             tready_i1,
  input             tlast_i1,
  input      [63:0] tdata_i1,

  // incoming port 2
  input             tvalid_i2,
  input             tready_i2,
  input             tlast_i2,
  input      [63:0] tdata_i2,

  input             link_initialized,
  input     [223:0] phy_debug,
  input             gtrx_disperr_or,
  input             gtrx_notintable_or,

  input             register_reset,
  input             reset_all_registers,
  input       [3:0] stats_address,

  output reg [31:0] stats_data
 );


  // {{{ local parameters -----------------

  // }}} End local parameters -------------


  // {{{ wire declarations ----------------
  reg [19:0] bit_counter20;
  reg        count_event10;
  reg        count_event20;

  wire       core_sent_pna     = phy_debug[160];
  wire       core_received_pna = phy_debug[161];
  wire       core_sent_pr      = phy_debug[162];
  wire       core_received_pr  = phy_debug[163];

  wire       active_beat_o1_d = tvalid_o1 && tready_o1;
  wire       active_beat_o2_d = tvalid_o2 && tready_o2;
  wire       active_beat_i1_d = tvalid_i1 && tready_i1;
  wire       active_beat_i2_d = tvalid_i2 && tready_i2;
  reg        active_beat_o1;
  reg        active_beat_o2;
  reg        active_beat_i1;
  reg        active_beat_i2;
  wire       packet_complete_o1_d = active_beat_o1_d && tlast_o1;
  wire       packet_complete_o2_d = active_beat_o2_d && tlast_o2;
  wire       packet_complete_i1_d = active_beat_i1_d && tlast_i1;
  wire       packet_complete_i2_d = active_beat_i2_d && tlast_i2;
  reg        packet_complete_o1;
  reg        packet_complete_o2;
  reg        packet_complete_i1;
  reg        packet_complete_i2;
  reg  [2:0] packet_complete_accum;
  reg        out_of_packet_o1;
  reg        out_of_packet_o2;
  reg        out_of_packet_i1;
  reg        out_of_packet_i2;
  reg        packet_is_request_o1;
  reg        packet_is_request_o2;
  reg        packet_is_request_i1;
  reg        packet_is_request_i2;
  wire       ftype_2_i1 = tdata_i1[55:52] == 4'h2;
  wire       ftype_2_i2 = tdata_i2[55:52] == 4'h2;
  wire       ftype_2_o1 = tdata_o1[55:52] == 4'h2;
  wire       ftype_2_o2 = tdata_o2[55:52] == 4'h2;
  wire       ftype_5_i1 = tdata_i1[55:52] == 4'h5;
  wire       ftype_5_i2 = tdata_i2[55:52] == 4'h5;
  wire       ftype_5_o1 = tdata_o1[55:52] == 4'h5;
  wire       ftype_5_o2 = tdata_o2[55:52] == 4'h5;
  wire       ftype_8_i1 = tdata_i1[55:52] == 4'h8;
  wire       ftype_8_i2 = tdata_i2[55:52] == 4'h8;
  wire       ftype_8_o1 = tdata_o1[55:52] == 4'h8;
  wire       ftype_8_o2 = tdata_o2[55:52] == 4'h8;

  // ADDR 0
  reg [31:0] instruction_count10;
  reg [31:0] instruction_count10_int;
  // ADDR 1
  reg [31:0] instruction_count20;
  reg [31:0] instruction_count20_int;
  // ADDR 2
  reg [31:0] active_count10_i1;
  reg [31:0] active_count10_i1_int;
  // ADDR 3
  reg [31:0] active_count10_i2;
  reg [31:0] active_count10_i2_int;
  // ADDR 4
  reg [31:0] active_count10_o1;
  reg [31:0] active_count10_o1_int;
  // ADDR 5
  reg [31:0] active_count10_o2;
  reg [31:0] active_count10_o2_int;
  // ADDR 6
  reg [31:0] total_pnas_sent;
  // ADDR 7
  reg [31:0] total_pnas_received;
  // ADDR 8
  reg [31:0] total_requests_sent;
  // ADDR 9
  reg [31:0] total_requests_received;
  // ADDR A
  reg [31:0] disp_error_count;
  // ADDR B
  reg [31:0] nit_error_count;
  // ADDR C
  reg [31:0] packet_retries_sent;
  // ADDR D
  reg [31:0] packet_retries_received;

  // }}} End wire declarations ------------


  // {{{ Commonly used signals ------------

  // 2^10, 2^20 counters
  always @(posedge log_clk) begin
    if (log_rst) begin
      bit_counter20 <= 0;
    end else begin
      bit_counter20 <= bit_counter20 + 1;
    end
  end
  always @(posedge log_clk) begin
    count_event20 <= &bit_counter20;
    count_event10 <= &bit_counter20[9:0];
  end


  // find the first cycle of a packet, determine FTYPE
  always @(posedge log_clk) begin
    if (log_rst) begin
      out_of_packet_o1 <= 1'b1;
      out_of_packet_o2 <= 1'b1;
      out_of_packet_i1 <= 1'b1;
      out_of_packet_i2 <= 1'b1;
    end else begin
      if (packet_complete_o1_d) begin
        out_of_packet_o1 <= 1'b1;
      end else if (active_beat_o1_d) begin
        out_of_packet_o1 <= 1'b0;
      end
      if (packet_complete_o2_d) begin
        out_of_packet_o2 <= 1'b1;
      end else if (active_beat_o2_d) begin
        out_of_packet_o2 <= 1'b0;
      end
      if (packet_complete_i1_d) begin
        out_of_packet_i1 <= 1'b1;
      end else if (active_beat_i1_d) begin
        out_of_packet_i1 <= 1'b0;
      end
      if (packet_complete_i2_d) begin
        out_of_packet_i2 <= 1'b1;
      end else if (active_beat_i2_d) begin
        out_of_packet_i2 <= 1'b0;
      end
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      packet_is_request_o1 <= 1'b0;
      packet_is_request_o2 <= 1'b0;
      packet_is_request_i1 <= 1'b0;
      packet_is_request_i2 <= 1'b0;
    end else begin
      if (out_of_packet_o1 && active_beat_o1_d &&
          (ftype_2_o1 || ftype_5_o1 || ftype_8_o1)) begin
        packet_is_request_o1 <= 1'b1;
      end else begin
        packet_is_request_o1 <= 1'b0;
      end
      if (out_of_packet_o2 && active_beat_o2_d &&
          (ftype_2_o2 || ftype_5_o2 || ftype_8_o2)) begin
        packet_is_request_o2 <= 1'b1;
      end else begin
        packet_is_request_o2 <= 1'b0;
      end
      if (out_of_packet_i1 && active_beat_i1_d &&
          (ftype_2_i1 || ftype_5_i1 || ftype_8_i1)) begin
        packet_is_request_i1 <= 1'b1;
      end else begin
        packet_is_request_i1 <= 1'b0;
      end
      if (out_of_packet_i2 && active_beat_i2_d &&
          (ftype_2_i2 || ftype_5_i2 || ftype_8_i2)) begin
        packet_is_request_i2 <= 1'b1;
      end else begin
        packet_is_request_i2 <= 1'b0;
      end
    end
  end


  // register combinatorial logic
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_beat_o1        <= 1'b0;
      active_beat_o2        <= 1'b0;
      active_beat_i1        <= 1'b0;
      active_beat_i2        <= 1'b0;
      packet_complete_o1    <= 1'b0;
      packet_complete_o2    <= 1'b0;
      packet_complete_i1    <= 1'b0;
      packet_complete_i2    <= 1'b0;
      packet_complete_accum <= 3'h0;
    end else begin
      active_beat_o1        <= active_beat_o1_d;
      active_beat_o2        <= active_beat_o2_d;
      active_beat_i1        <= active_beat_i1_d;
      active_beat_i2        <= active_beat_i2_d;
      packet_complete_o1    <= packet_complete_o1_d;
      packet_complete_o2    <= packet_complete_o2_d;
      packet_complete_i1    <= packet_complete_i1_d;
      packet_complete_i2    <= packet_complete_i2_d;
      packet_complete_accum <= {2'h0, packet_complete_o1} + {2'h0, packet_complete_o2} +
                               {2'h0, packet_complete_i1} + {2'h0, packet_complete_i2};
    end
  end

  // }}} End commonly used signals --------


  // {{{ Data output MUXing ---------------
  always @(posedge log_clk) begin
    case (stats_address)
      4'h0    : stats_data <= instruction_count10;
      4'h1    : stats_data <= instruction_count20;
      4'h2    : stats_data <= active_count10_i1;
      4'h3    : stats_data <= active_count10_i2;
      4'h4    : stats_data <= active_count10_o1;
      4'h5    : stats_data <= active_count10_o2;
      4'h6    : stats_data <= total_pnas_sent;
      4'h7    : stats_data <= total_pnas_received;
      4'h8    : stats_data <= total_requests_sent;
      4'h9    : stats_data <= total_requests_received;
      4'ha    : stats_data <= disp_error_count;
      4'hb    : stats_data <= nit_error_count;
      4'hc    : stats_data <= packet_retries_sent;
      4'hd    : stats_data <= packet_retries_received;
      default : stats_data <= 32'hA_BAD_ADD1;
    endcase
  end
  // }}} End Data output MUXing -----------


  // ADDR 0 number of instructions over the past 2^10 cycles
  always @(posedge log_clk) begin
    if (log_rst) begin
      instruction_count10_int <= 0;
    end else if (count_event10) begin
      instruction_count10_int <= 0;
    end else  begin
      instruction_count10_int <= instruction_count10_int + {29'h0, packet_complete_accum};
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      instruction_count10 <= 0;
    end else if (count_event10) begin
      instruction_count10 <= instruction_count10_int;
    end
  end


  // ADDR 1 number of instructions over the past 2^20 cycles
  always @(posedge log_clk) begin
    if (log_rst) begin
      instruction_count20_int <= 0;
    end else if (count_event20) begin
      instruction_count20_int <= 0;
    end else begin
      instruction_count20_int <= instruction_count20_int + {29'h0, packet_complete_accum};
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      instruction_count20 <= 0;
    end else if (count_event20) begin
      instruction_count20 <= instruction_count20_int;
    end
  end


  // ADDR 2 number of active cycles over the past 2^10 cycles
  // port o1
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_count10_o1_int <= 0;
    end else if (count_event10) begin
      active_count10_o1_int <= 0;
    end else if (active_beat_o1) begin
      active_count10_o1_int <= active_count10_o1_int + 1;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_count10_o1 <= 0;
    end else if (count_event10) begin
      active_count10_o1 <= active_count10_o1_int;
    end
  end


  // ADDR 3 number of active cycles over the past 2^10 cycles
  // port o2
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_count10_o2_int <= 0;
    end else if (count_event10) begin
      active_count10_o2_int <= 0;
    end else if (active_beat_o2) begin
      active_count10_o2_int <= active_count10_o2_int + 1;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_count10_o2 <= 0;
    end else if (count_event10) begin
      active_count10_o2 <= active_count10_o2_int;
    end
  end


  // ADDR 4 number of active cycles over the past 2^10 cycles
  // port i1
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_count10_i1_int <= 0;
    end else if (count_event10) begin
      active_count10_i1_int <= 0;
    end else if (active_beat_i1) begin
      active_count10_i1_int <= active_count10_i1_int + 1;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_count10_i1 <= 0;
    end else if (count_event10) begin
      active_count10_i1 <= active_count10_i1_int;
    end
  end


  // ADDR 5 number of active cycles over the past 2^10 cycles
  // port i2
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_count10_i2_int <= 0;
    end else if (count_event10) begin
      active_count10_i2_int <= 0;
    end else if (active_beat_i2) begin
      active_count10_i2_int <= active_count10_i2_int + 1;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst) begin
      active_count10_i2 <= 0;
    end else if (count_event10) begin
      active_count10_i2 <= active_count10_i2_int;
    end
  end


  // ADDR 6 total number of PNAs issued
  always @(posedge phy_clk) begin
    if (phy_rst) begin
      total_pnas_sent <= 0;
    end else if ((stats_address == 4'h6 && register_reset) || reset_all_registers) begin
      total_pnas_sent <= 0;
    end else if (core_sent_pna && ~&total_pnas_sent) begin
      total_pnas_sent <= total_pnas_sent + 1;
    end
  end


  // ADDR 7 total PNAs received
  always @(posedge phy_clk) begin
    if (phy_rst) begin
      total_pnas_received <= 0;
    end else if ((stats_address == 4'h7 && register_reset) || reset_all_registers) begin
      total_pnas_received <= 0;
    end else if (core_received_pna && ~&total_pnas_received) begin
      total_pnas_received <= total_pnas_received + 1;
    end
  end


  // ADDR 8 total requests sent overall
  always @(posedge log_clk) begin
    if (log_rst) begin
      total_requests_sent <= 0;
    end else if ((stats_address == 4'h8 && register_reset) || reset_all_registers) begin
      total_requests_sent <= 0;
    end else begin
      total_requests_sent <= total_requests_sent + packet_is_request_o1 + packet_is_request_o2;
    end
  end


  // ADDR 9 total requests sent overall
  always @(posedge log_clk) begin
    if (log_rst) begin
      total_requests_received <= 0;
    end else if ((stats_address == 4'h9 && register_reset) || reset_all_registers) begin
      total_requests_received <= 0;
    end else begin
      total_requests_received <= total_requests_received + packet_is_request_i1 + packet_is_request_i2;
    end
  end


  // ADDR A number of disparity errors detected
  always @(posedge gt_pcs_clk) begin
    if (phy_rst) begin
      disp_error_count <= 0;
    end else if ((stats_address == 4'ha && register_reset) || reset_all_registers) begin
      disp_error_count <= 0;
    end else if (link_initialized && gtrx_disperr_or) begin
      disp_error_count <= disp_error_count + 1;
    end
  end


  // ADDR B number of not in table errors detected
  always @(posedge gt_pcs_clk) begin
    if (phy_rst) begin
      nit_error_count <= 0;
    end else if ((stats_address == 4'hb && register_reset) || reset_all_registers) begin
      nit_error_count <= 0;
    end else if (link_initialized && gtrx_notintable_or) begin
      nit_error_count <= nit_error_count + 1;
    end
  end


  // ADDR C number of packet retries sent
  always @(posedge phy_clk) begin
    if (phy_rst) begin
      packet_retries_sent <= 0;
    end else if ((stats_address == 4'hc && register_reset) || reset_all_registers) begin
      packet_retries_sent <= 0;
    end else if (core_sent_pr) begin
      packet_retries_sent <= packet_retries_sent + 1;
    end
  end


  // ADDR D number of packet retries received
  always @(posedge phy_clk) begin
    if (phy_rst) begin
      packet_retries_received <= 0;
    end else if ((stats_address == 4'hd && register_reset) || reset_all_registers) begin
      packet_retries_received <= 0;
    end else if (core_received_pr) begin
      packet_retries_received <= packet_retries_received + 1;
    end
  end


endmodule
// {{{ DISCLAIMER OF LIABILITY
// -----------------------------------------------------------------
// (c) Copyright 2010 Xilinx, Inc. All rights reserved.
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
// }}}

