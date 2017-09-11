localparam NUM_SWRITES = SEND_SWRITE ? 37 : 0;
localparam NUM_NWRITERS = SEND_NWRITER ? 19 : 0;
localparam NUM_NWRITES = SEND_NWRITE ? 19 : 0;
localparam NUM_NREADS = SEND_NREAD ? 26 : 0;
localparam NUM_DBS = SEND_DB ? 2 : 0;
localparam NUM_MSGS = SEND_MSG ? 17 : 0;
localparam NUM_FTYPE9 = SEND_FTYPE9 ? 1 : 0;

localparam NUMBER_OF_INSTRUCTIONS = NUM_SWRITES + NUM_NWRITERS + NUM_NWRITES + NUM_NREADS + NUM_DBS + NUM_MSGS + NUM_FTYPE9;

localparam [64*37-1:0] swrite_instruction = {
  // RSVD,   FTYPE, TTYPE,  ADDRESS,       SIZE
  // SWRITEs
  {12'h000, SWRITE, 4'h0,   36'h000000777, 8'd0},  
  {12'h000, SWRITE, 4'h0,   36'h000008806, 8'd0},  
  {12'h000, SWRITE, 4'h0,   36'h000000125, 8'd0},  
  {12'h000, SWRITE, 4'h0,   36'h000000124, 8'd0},  
  {12'h000, SWRITE, 4'h0,   36'h000000123, 8'd0},  
  {12'h000, SWRITE, 4'h0,   36'h000000122, 8'd0},  
  {12'h000, SWRITE, 4'h0,   36'h000000121, 8'd0},  
  {12'h000, SWRITE, 4'h0,   36'h000000120, 8'd0},  
  {12'h000, SWRITE, 4'h0,   36'h000000126, 8'd1},  
  {12'h000, SWRITE, 4'h0,   36'h000000124, 8'd1},  
  {12'h000, SWRITE, 4'h0,   36'h000000122, 8'd1},  
  {12'h000, SWRITE, 4'h0,   36'h000004350, 8'd1},  
  {12'h000, SWRITE, 4'h0,   36'h000004355, 8'd2},  
  {12'h000, SWRITE, 4'h0,   36'h000012300, 8'd2},  
  {12'h000, SWRITE, 4'h0,   36'h000012304, 8'd3},  
  {12'h000, SWRITE, 4'h0,   36'h000345000, 8'd3},  
  {12'h000, SWRITE, 4'h0,   36'h000345003, 8'd4},  
  {12'h000, SWRITE, 4'h0,   36'h004550000, 8'd4},  
  {12'h000, SWRITE, 4'h0,   36'h004550002, 8'd5},  
  {12'h000, SWRITE, 4'h0,   36'h198877600, 8'd5},  
  {12'h000, SWRITE, 4'h0,   36'h198877601, 8'd6},  
  {12'h000, SWRITE, 4'h0,   36'h2ABBCCDD8, 8'd6},  
  {12'h000, SWRITE, 4'h0,   36'h2ABBCCDD8, 8'd7},  
  {12'h000, SWRITE, 4'h0,   36'h2ABBCCDD8, 8'd15}, 
  {12'h000, SWRITE, 4'h0,   36'h2ABBCCDD8, 8'd31}, 
  {12'h000, SWRITE, 4'h0,   36'h120000600, 8'd63}, 
  {12'h000, SWRITE, 4'h0,   36'h230000600, 8'd95}, 
  {12'h000, SWRITE, 4'h0,   36'h340000600, 8'd127},
  {12'h000, SWRITE, 4'h0,   36'h450000600, 8'd255},
  {12'h000, SWRITE, 4'h0,   36'h560000600, 8'd15}, 
  {12'h000, SWRITE, 4'h0,   36'h670000600, 8'd31}, 
  {12'h000, SWRITE, 4'h0,   36'h780000600, 8'd63}, 
  {12'h000, SWRITE, 4'h0,   36'h780000600, 8'd95}, 
  {12'h000, SWRITE, 4'h0,   36'h890000600, 8'd127},
  {12'h000, SWRITE, 4'h0,   36'h9A0000600, 8'd255},
  {12'h000, SWRITE, 4'h0,   36'hAB0000600, 8'd15}, 
  {12'h000, SWRITE, 4'h0,   36'hCD0000600, 8'd15}}; 

localparam [64*19-1:0] nwriter_instruction = {
  // NWRITERs
  {12'h000, NWRITE, TNWR_R, 36'h000000777, 8'd0},
  {12'h000, NWRITE, TNWR_R, 36'h000008806, 8'd0},
  {12'h000, NWRITE, TNWR_R, 36'h000000125, 8'd0},
  {12'h000, NWRITE, TNWR_R, 36'h000000124, 8'd0},
  {12'h000, NWRITE, TNWR_R, 36'h000000123, 8'd0},
  {12'h000, NWRITE, TNWR_R, 36'h000000122, 8'd0},
  {12'h000, NWRITE, TNWR_R, 36'h000000121, 8'd0},
  {12'h000, NWRITE, TNWR_R, 36'h000000120, 8'd0},
  {12'h000, NWRITE, TNWR_R, 36'h000000126, 8'd1},
  {12'h000, NWRITE, TNWR_R, 36'h000000124, 8'd1},
  {12'h000, NWRITE, TNWR_R, 36'h000000122, 8'd1},
  {12'h000, NWRITE, TNWR_R, 36'h000004350, 8'd1},
  {12'h000, NWRITE, TNWR_R, 36'h000004355, 8'd2},
  {12'h000, NWRITE, TNWR_R, 36'h000012300, 8'd2},
  {12'h000, NWRITE, TNWR_R, 36'h000012304, 8'd3},
  {12'h000, NWRITE, TNWR_R, 36'h000345000, 8'd3},
  {12'h000, NWRITE, TNWR_R, 36'h000345003, 8'd4},
  {12'h000, NWRITE, TNWR_R, 36'h004550000, 8'd4},
  {12'h000, NWRITE, TNWR_R, 36'h004550002, 8'd5}};
  
localparam [64*19-1:0] nwrite_instruction = {
  // NWRITEs
  {12'h000, NWRITE, TNWR,   36'h198877600, 8'd5},
  {12'h000, NWRITE, TNWR,   36'h198877601, 8'd6},
  {12'h000, NWRITE, TNWR,   36'h2ABBCCDD8, 8'd6},
  {12'h000, NWRITE, TNWR,   36'h2ABBCCDD8, 8'd7},
  {12'h000, NWRITE, TNWR,   36'h2ABBCCDD8, 8'd15},
  {12'h000, NWRITE, TNWR,   36'h2ABBCCDD8, 8'd31},
  {12'h000, NWRITE, TNWR,   36'h120000600, 8'd63},
  {12'h000, NWRITE, TNWR,   36'h230000600, 8'd95},
  {12'h000, NWRITE, TNWR,   36'h340000600, 8'd127},
  {12'h000, NWRITE, TNWR,   36'h450000600, 8'd255},
  {12'h000, NWRITE, TNWR,   36'h560000600, 8'd15},
  {12'h000, NWRITE, TNWR,   36'h670000600, 8'd31},
  {12'h000, NWRITE, TNWR,   36'h780000600, 8'd63},
  {12'h000, NWRITE, TNWR,   36'h890000600, 8'd95},
  {12'h000, NWRITE, TNWR,   36'h9A0000600, 8'd127},
  {12'h000, NWRITE, TNWR,   36'hAB0000600, 8'd255},
  {12'h000, NWRITE, TNWR,   36'hBC0000600, 8'd15},
  {12'h000, NWRITE, TNWR,   36'hCD0000600, 8'd15},
  {12'h000, NWRITE, TNWR,   36'hDE0000600, 8'd15}};

localparam [64*26-1:0] nread_instruction = {
  // NREADs
  {12'h000, NREAD,  TNRD,   36'h000002307, 8'd00},
  {12'h000, NREAD,  TNRD,   36'h000002406, 8'd00},
  {12'h000, NREAD,  TNRD,   36'h000002505, 8'd00},
  {12'h000, NREAD,  TNRD,   36'h000002604, 8'd00},
  {12'h000, NREAD,  TNRD,   36'h000002703, 8'd00},
  {12'h000, NREAD,  TNRD,   36'h000002802, 8'd00},
  {12'h000, NREAD,  TNRD,   36'h000002301, 8'd00},
  {12'h000, NREAD,  TNRD,   36'h000002400, 8'd00},
  {12'h000, NREAD,  TNRD,   36'h000002506, 8'd01},
  {12'h000, NREAD,  TNRD,   36'h000002604, 8'd01},
  {12'h000, NREAD,  TNRD,   36'h000002702, 8'd01},
  {12'h000, NREAD,  TNRD,   36'h000002800, 8'd01},
  {12'h000, NREAD,  TNRD,   36'h000002305, 8'd02},
  {12'h000, NREAD,  TNRD,   36'h000002400, 8'd02},
  {12'h000, NREAD,  TNRD,   36'h000002504, 8'd03},
  {12'h000, NREAD,  TNRD,   36'h000002600, 8'd03},
  {12'h000, NREAD,  TNRD,   36'h000002703, 8'd04},
  {12'h000, NREAD,  TNRD,   36'h000002800, 8'd04},
  {12'h000, NREAD,  TNRD,   36'h000002502, 8'd05},
  {12'h000, NREAD,  TNRD,   36'h000002600, 8'd05},
  {12'h000, NREAD,  TNRD,   36'h000002701, 8'd06},
  {12'h000, NREAD,  TNRD,   36'h000002800, 8'd06},
  {12'h000, NREAD,  TNRD,   36'h0000023F0, 8'd07},
  {12'h000, NREAD,  TNRD,   36'h000002400, 8'd15},
  {12'h000, NREAD,  TNRD,   36'h000002500, 8'd31},
  {12'h000, NREAD,  TNRD,   36'h000002600, 8'd63}};

localparam [64*2-1:0] db_instruction = {
  // DOORBELLs
  {12'h000, DOORB,  4'b0,   36'h0DBDB0000, 8'd01},
  {12'h000, DOORB,  4'b0,   36'h044440000, 8'd01}};
  
localparam [64*17-1:0] msg_instruction = {
  // MESSAGEs
  {12'h000, MESSG,  4'b0,   36'h000000002, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000012, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000022, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000002, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000012, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000022, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000002, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000012, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000022, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000002, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000012, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000022, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000002, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000012, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000022, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000002, 8'd07},
  {12'h000, MESSG,  4'b0,   36'h000000012, 8'd07}};

localparam [64*1-1:0] ftype9_instruction = {
  // FTYPE9 
  {12'h000, FTYPE9,  4'b0,   36'h0DBDB0100, 8'd7}};
// {{{ DISCLAIMER OF LIABILITY
// -----------------------------------------------------------------
// (c) Copyright 2012 Xilinx, Inc. All rights reserved.
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
