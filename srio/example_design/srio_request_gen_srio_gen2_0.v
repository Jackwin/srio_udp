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
`timescale 1ps/1ps

module srio_request_gen_srio_gen2_0
  #(
    parameter     SEND_SWRITE   = 0,
    parameter     SEND_NWRITER  = 0,
    parameter     SEND_NWRITE   = 0,
    parameter     SEND_NREAD    = 0,
    parameter     SEND_DB       = 0,
    parameter     SEND_FTYPE9   = 0,
    parameter     SEND_MSG      = 0)
   (
    input             log_clk,
    input             log_rst,

    input      [15:0] deviceid,
    input      [15:0] dest_id,
    input      [15:0] source_id,
    input             id_override,

    output reg        val_ireq_tvalid,
    input             val_ireq_tready,
    output reg        val_ireq_tlast,
    output reg [63:0] val_ireq_tdata,
    output      [7:0] val_ireq_tkeep,
    output     [31:0] val_ireq_tuser,

    input             val_iresp_tvalid,
    output reg        val_iresp_tready,
    input             val_iresp_tlast,
    input      [63:0] val_iresp_tdata,
    input       [7:0] val_iresp_tkeep,
    input      [31:0] val_iresp_tuser,

    input             link_initialized,
    input             go,
    input      [33:0] user_addr,
    input       [3:0] user_ftype,
    input       [3:0] user_ttype,
    input       [7:0] user_size,
    input      [63:0] user_data,

    output reg        request_autocheck_error,
    output reg        request_done
   );

  // {{{ local parameters -----------------

  localparam [3:0] NREAD  = 4'h2;
  localparam [3:0] NWRITE = 4'h5;
  localparam [3:0] SWRITE = 4'h6;
  localparam [3:0] DOORB  = 4'hA;
  localparam [3:0] MESSG  = 4'hB;
  localparam [3:0] RESP   = 4'hD;
  localparam [3:0] FTYPE9 = 4'h9;

  localparam [3:0] TNWR   = 4'h4;
  localparam [3:0] TNWR_R = 4'h5;
  localparam [3:0] TNRD   = 4'h4;

  localparam [3:0] TNDATA = 4'h0;
  localparam [3:0] MSGRSP = 4'h1;
  localparam [3:0] TWDATA = 4'h8;

  // }}} End local parameters -------------


  // {{{ wire declarations ----------------
  reg  [15:0] log_rst_shift;
  wire        log_rst_q = log_rst_shift[15];

  //synthesis attribute ram_style of instruction is distributed
  wire [63:0] instruction [0:511];
  `include "instruction_list.vh"

  reg  [12:0] link_initialized_cnt;
  wire        link_initialized_delay = link_initialized_cnt[12];

  wire        ireq_advance_condition  = val_ireq_tready && val_ireq_tvalid;
  wire        iresp_advance_condition = val_iresp_tready && val_iresp_tvalid;

  // request side
  wire [63:0] request_data_out;
  reg  [47:0] request_data_out_q; // upper 63:48 unused
  reg         auto_advance_data;
  reg   [8:0] request_address;

  wire [15:0] src_id;
  wire  [1:0] prio;
  wire  [7:0] tid;
  wire [35:0] srio_addr;
  wire [63:0] header_beat;

  wire  [3:0] current_ftype;
  wire  [3:0] current_ttype;
  wire  [7:0] current_size;
  wire  [15:0] current_size_ftype9;
  wire  [4:0] number_of_data_beats;
  wire  [12:0] number_of_data_beats_ftype9;
  reg   [4:0] number_of_data_beats_q;
  reg   [12:0] number_of_data_beats_q_ftype9;
  reg   [5:0] current_beat_cnt;
  reg   [13:0] current_beat_cnt_ftype9;

  reg         last_packet_beat_q, last_packet_beat_qq, last_packet_beat_qqq;
  reg   [7:0] data_beat, data_beat_q;
  reg  [15:0] instruction_cnt;
  reg         sent_all_packets;

  reg         go_q;

  // response check side
  reg         expecting_a_response;
  reg   [8:0] write_queue_addr;
  reg   [8:0] read_queue_addr;
  wire [63:0] write_queue_data_d;
  reg  [63:0] write_queue_data;
  wire [63:0] read_queue_data;
  reg  [63:0] read_queue_data_q;
  reg         compare_received;
  wire  [3:0] expected_ftype;
  wire  [7:0] expected_tid;
  wire  [7:0] expected_size;
  reg         delay_assert_tready;

  // }}} End wire declarations ------------


  // {{{ Common-use Signals ---------------
  // Initialize instruction list
  genvar ii;
  generate
    for (ii = 0; ii < 512; ii = ii + 1) begin : instruction_gen
        // Load SWRITEs
        if(ii < NUM_SWRITES) begin
         assign instruction[ii] = swrite_instruction[(ii+1)*64-1:ii*64];
        // Load NWRITE_Rs
        end else if(ii < (NUM_SWRITES + NUM_NWRITERS)) begin
         assign  instruction[ii] = nwriter_instruction[(ii-NUM_SWRITES+1)*64-1:(ii-NUM_SWRITES)*64];
        // Load NWRITEs
        end else if(ii < (NUM_SWRITES + NUM_NWRITERS + NUM_NWRITES)) begin
         assign  instruction[ii] = nwrite_instruction[(ii-NUM_SWRITES-NUM_NWRITERS+1)*64-1:(ii-NUM_SWRITES-NUM_NWRITERS)*64];
        // Load NREADs
        end else if(ii < (NUM_SWRITES + NUM_NWRITERS + NUM_NWRITES + NUM_NREADS)) begin
         assign  instruction[ii] = nread_instruction[(ii-NUM_SWRITES-NUM_NWRITERS-NUM_NWRITES+1)*64-1:(ii-NUM_SWRITES-NUM_NWRITERS-NUM_NWRITES)*64];
        // Load DBs
        end else if(ii < (NUM_SWRITES + NUM_NWRITERS + NUM_NWRITES + NUM_NREADS + NUM_DBS)) begin
         assign  instruction[ii] = db_instruction[(ii-NUM_SWRITES-NUM_NWRITERS-NUM_NWRITES-NUM_NREADS+1)*64-1:(ii-NUM_SWRITES-NUM_NWRITERS-NUM_NWRITES-NUM_NREADS)*64];
        // Load MSGs
        end else if(ii < (NUM_SWRITES + NUM_NWRITERS + NUM_NWRITES + NUM_NREADS + NUM_DBS + NUM_MSGS)) begin
         assign  instruction[ii] = msg_instruction[(ii-NUM_SWRITES-NUM_NWRITERS-NUM_NWRITES-NUM_NREADS-NUM_DBS+1)*64-1:(ii-NUM_SWRITES-NUM_NWRITERS-NUM_NWRITES-NUM_NREADS-NUM_DBS)*64];
        end else if(ii < (NUM_SWRITES + NUM_NWRITERS + NUM_NWRITES + NUM_NREADS + NUM_DBS + NUM_MSGS + NUM_FTYPE9)) begin
         assign  instruction[ii] = ftype9_instruction[(ii-NUM_SWRITES-NUM_NWRITERS-NUM_NWRITES-NUM_NREADS-NUM_DBS-NUM_MSGS+1)*64-1:(ii-NUM_SWRITES-NUM_NWRITERS-NUM_NWRITES-NUM_NREADS-NUM_DBS-NUM_MSGS)*64];
        end else begin
         assign  instruction[ii] = 64'h0;
        end
    end
  endgenerate

  // Simple Assignments
  assign val_ireq_tkeep  = 8'hFF;
  assign src_id          = id_override ? source_id : deviceid;
  assign prio            = 2'h1;
  assign val_ireq_tuser  = {src_id, dest_id};
  assign tid             = request_address[7:0];
  assign srio_addr       = go ? user_addr : request_data_out_q[43:8];
  assign current_ftype   = go ? user_ftype : request_data_out[51:48];
  assign current_ttype   = go ? user_ttype : request_data_out_q[47:44];
  assign current_size    = go ? user_size : request_data_out_q[7:0];
  assign current_size_ftype9    = go ? {user_size,user_size} : request_data_out_q[23:8];
  //                        //Fixed CR# 799600, 12/15/2014, Added ftype switch for message in below header in place of plain "tid" field.
  assign header_beat     = {((current_ftype == MESSG)? request_data_out[59:52] : tid), current_ftype, current_ttype, 1'b0, prio, 1'b0, current_size, srio_addr};
  // End Simple Assignments

  always @(posedge log_clk or posedge log_rst) begin
    if (log_rst)
      log_rst_shift <= 16'hFFFF;
    else
      log_rst_shift <= {log_rst_shift[14:0], 1'b0};
  end

  always @(posedge log_clk) begin
    if (log_rst_q) begin
      last_packet_beat_q       <= 1'b1;
      last_packet_beat_qq      <= 1'b1;
      last_packet_beat_qqq     <= 1'b1;
      number_of_data_beats_q   <= 5'h0;
      number_of_data_beats_q_ftype9   <= 13'h0;
      read_queue_data_q        <= 64'h0;
      go_q                     <= 1'b0;
    end else begin
      last_packet_beat_q       <= ireq_advance_condition && val_ireq_tlast;
      last_packet_beat_qq      <= last_packet_beat_q;
      last_packet_beat_qqq     <= last_packet_beat_qq || !link_initialized_delay;
      number_of_data_beats_q   <= number_of_data_beats;
      number_of_data_beats_q_ftype9   <= number_of_data_beats_ftype9;
      read_queue_data_q        <= read_queue_data;
      go_q                     <= go;
    end
  end


  // put a sufficient delay on the initialization to improve simulation time.
  // Not needed for actual hardware but does no damage if kept.
  always @(posedge log_clk) begin
    if (log_rst_q) begin
      link_initialized_cnt <= 0;
    end else if (link_initialized && !link_initialized_delay) begin
      link_initialized_cnt <= link_initialized_cnt + 1'b1;
    end else if (!link_initialized) begin
      link_initialized_cnt <= 0;
    end
  end

  // }}} End Common-use Signals -----------


  // {{{ Request Packet Formatter ---------
  assign number_of_data_beats = current_beat_cnt == 0 ? current_size[7:3] : number_of_data_beats_q;

  assign number_of_data_beats_ftype9 = current_beat_cnt_ftype9 == 0 ? current_size_ftype9[15:3] : number_of_data_beats_q_ftype9;

  always @(posedge log_clk) begin
    if (log_rst_q) begin
      current_beat_cnt <= 6'h0;
    end else if (ireq_advance_condition && val_ireq_tlast) begin
      current_beat_cnt <= 6'h0;
    end else if (ireq_advance_condition) begin
      current_beat_cnt <= current_beat_cnt + 1'b1;
    end
  end

  always @(posedge log_clk) begin
    if (log_rst_q) begin
      current_beat_cnt_ftype9 <= 14'h000;
    end else if (ireq_advance_condition && val_ireq_tlast) begin
      current_beat_cnt_ftype9 <= 14'h000;
    end else if (ireq_advance_condition) begin
      current_beat_cnt_ftype9 <= current_beat_cnt_ftype9 + 1'b1;
    end
  end

wire extended_number_of_data_beats_ftype9;

assign extended_number_of_data_beats_ftype9 = {1'b0, number_of_data_beats_ftype9};

  always @(posedge log_clk) begin
    if (log_rst_q) begin
      val_ireq_tlast  <= 1'b0;
    end else if (((current_ftype == NREAD) || (current_ftype == DOORB)) && current_beat_cnt == 6'h00) begin 
      val_ireq_tlast  <= !(ireq_advance_condition && val_ireq_tlast);
    end else if ((current_beat_cnt == {1'b0, number_of_data_beats} && ireq_advance_condition && (current_ftype != FTYPE9)) || ((current_beat_cnt_ftype9 == extended_number_of_data_beats_ftype9) && ireq_advance_condition && (current_ftype == FTYPE9) )) begin
      val_ireq_tlast  <= !val_ireq_tlast;
    end else if (!val_ireq_tready) begin
      val_ireq_tlast  <= val_ireq_tlast;
    end else if (val_ireq_tready || !val_ireq_tvalid) begin
      val_ireq_tlast  <= 1'b0;
    end
  end
  always @(posedge log_clk) begin
    if ((current_beat_cnt == 0 && !ireq_advance_condition && (current_ftype != FTYPE9)) || (current_beat_cnt_ftype9 == 0 && !ireq_advance_condition && (current_ftype == FTYPE9))) begin
      val_ireq_tdata  <= header_beat;
    end else if (go) begin
      val_ireq_tdata  <= user_data;
    end else begin
      val_ireq_tdata  <= {8{data_beat}};
    end
  end
  always @* begin
    data_beat = data_beat_q;
    if (ireq_advance_condition && current_beat_cnt != 0) begin
      data_beat = data_beat_q + 1'b1;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst_q) begin
      data_beat_q <= 8'h00;
    end else begin
      data_beat_q <= data_beat;
    end
  end

  always @(posedge log_clk) begin
    if (log_rst_q) begin
      val_ireq_tvalid  <= 1'b0;
      instruction_cnt  <= 16'h0;
      sent_all_packets <= 1'b0;
    end else if (link_initialized_delay && instruction_cnt < NUMBER_OF_INSTRUCTIONS && last_packet_beat_qqq) begin
      val_ireq_tvalid  <= 1'b1;
    end else if (ireq_advance_condition && val_ireq_tlast) begin
      val_ireq_tvalid  <= 1'b0;
      instruction_cnt  <= instruction_cnt + 1'b1;
    end else if (go && !go_q) begin
      val_ireq_tvalid  <= 1'b1;
    end else if (instruction_cnt == NUMBER_OF_INSTRUCTIONS) begin
      sent_all_packets <= 1'b1;
    end
  end

  // }}} End Request Packet Formatter -----


  // {{{ Request Data Storage -------------
  always @(posedge log_clk) begin
    if (log_rst_q) begin
      request_address <= 9'h0;
    end else if ((ireq_advance_condition && current_beat_cnt == 0 && (current_ftype != FTYPE9)) || ((current_beat_cnt_ftype9 == extended_number_of_data_beats_ftype9 - 1'b1) && ireq_advance_condition && (current_ftype == FTYPE9))) begin
      request_address <= request_address + 1'b1;
    end
  end

  assign request_data_out = instruction[request_address];

  always @ (posedge log_clk) begin
    if (ireq_advance_condition || auto_advance_data || last_packet_beat_qq)
      request_data_out_q <= request_data_out[47:0];
  end
  always @ (posedge log_clk) begin
    if (log_rst_q) begin
      auto_advance_data <= 1'b1;
    end else if (ireq_advance_condition) begin
      auto_advance_data <= 1'b0;
    end
  end
  // }}} End of Request Data Storage ------


  // {{{ Response Queue -------------------

  assign write_queue_data_d = {44'h0, tid, current_ftype, current_size};
  always @ (posedge log_clk) begin
    write_queue_data <= write_queue_data_d;
  end

  RAMB36SDP #(
   .SIM_COLLISION_CHECK("NONE"),
   .EN_ECC_READ("FALSE"),
   .EN_ECC_WRITE("FALSE")
  )
  response_queue_inst (
    .DI        (write_queue_data),
    .DIP       (8'h0),
    .RDADDR    (read_queue_addr),
    .RDCLK     (log_clk),
    .RDEN      (1'b1),
    .REGCE     (1'b1),
    .SSR       (log_rst),
    .WE        ({8{expecting_a_response}}),
    .WRADDR    (write_queue_addr),
    .WRCLK     (log_clk),
    .WREN      (expecting_a_response),

    .DO        (read_queue_data),
    .DOP       (),

    .ECCPARITY (),
    .SBITERR   (),
    .DBITERR   ()
  );


  assign expected_tid   = read_queue_data_q[19:12];
  assign expected_ftype = read_queue_data_q[11:8];
  assign expected_size  = read_queue_data_q[7:0];
  // }}} End of Response Queue ------------


  // {{{ Response Side Check --------------

  // collect outgoing requests that require a response, queue them
  always @(posedge log_clk) begin
    if (log_rst_q) begin
      expecting_a_response <= 1'b0;
    end else if (current_beat_cnt == 0 && ireq_advance_condition) begin
      expecting_a_response <= (current_ftype == NREAD) ||
                              (current_ftype == DOORB) ||
                              (current_ftype == MESSG) ||
                              ((current_ftype == NWRITE) && (current_ttype == TNWR_R));
    end else begin
      expecting_a_response <= 1'b0;
    end
  end
  always @(posedge log_clk) begin
    if (log_rst_q) begin
      write_queue_addr <= 9'h000;
    end else if (expecting_a_response) begin
      write_queue_addr <= write_queue_addr + 1;
    end
  end

  always @(posedge log_clk) begin
    if (log_rst_q) begin
      read_queue_addr  <= 9'h000;
      request_done     <= 1'b0;
      compare_received <= 1'b1;
    end else if (iresp_advance_condition && val_iresp_tlast && sent_all_packets &&
                 (write_queue_addr == read_queue_addr + 1)) begin
      request_done     <= 1'b1;
      compare_received <= 1'b0;
    end else if (sent_all_packets && (write_queue_addr == read_queue_addr)) begin
      request_done     <= 1'b1;
      compare_received <= 1'b0;
    end else if (iresp_advance_condition && val_iresp_tlast && !request_autocheck_error) begin
      read_queue_addr  <= read_queue_addr + 1;
      compare_received <= 1'b1;
    end else if (iresp_advance_condition) begin
      compare_received <= 1'b0;
    end
  end

  always @ (posedge log_clk) begin
    if (log_rst_q) begin
      request_autocheck_error <= 1'b0;
    end else if (compare_received && iresp_advance_condition) begin
      if(expected_tid != val_iresp_tdata[63:56]) begin
        // TID mismatch means an error unless it's a message response (MSGs don't use TID)
        if (!(expected_ftype == MESSG) || !(val_iresp_tdata[51:48] == MSGRSP)) begin
          request_autocheck_error <= 1'b1;
          $display ("\t *** TID mismatch Error ***");
        end
      // expecting a Read response
      end else if (expected_ftype == NREAD && !(val_iresp_tdata[51:48] == TWDATA)) begin
        request_autocheck_error <= 1'b1;
      $display ("\t *** NREAD Read Response Not Received ***");
      // expecting a Response without data
      end else if (expected_ftype == NWRITE && !(val_iresp_tdata[51:48] == TNDATA)) begin
        request_autocheck_error <= 1'b1;
      $display ("\t *** NWRITE Response Without Data Error ***");
      // expecting a Response without data
      end else if (expected_ftype == DOORB && !(val_iresp_tdata[51:48] == TNDATA)) begin
        request_autocheck_error <= 1'b1;
      $display ("\t *** DOORB Response Without Data Error ***");
      end
    end
  end

  always @ (posedge log_clk) begin
    if (log_rst_q) begin
      val_iresp_tready    <= 1'b0;
      delay_assert_tready <= 1'b0;

    end else if (iresp_advance_condition && val_iresp_tlast) begin
      val_iresp_tready    <= 1'b0;
      delay_assert_tready <= 1'b1;
    end else if (delay_assert_tready) begin
      val_iresp_tready    <= 1'b0;
      delay_assert_tready <= 1'b0;
    end else begin
      val_iresp_tready    <= 1'b1;
      delay_assert_tready <= 1'b0;
    end
  end

  // }}} End Response Side Check ----------


endmodule
// {{{ DISCLAIMER OF LIABILITY
// -----------------------------------------------------------------
// (c) Copyright 2010-2011 Xilinx, Inc. All rights reserved.
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

