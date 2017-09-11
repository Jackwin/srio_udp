`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/31/2016 12:45:10 PM
// Design Name: 
// Module Name: sync_block
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

(* dont_touch = "yes" *)
module sync_block
  #( parameter   C_NUM_SYNC_REGS = 5 )
  (
    input   wire  clk,
    input   wire  data_in,
    output  wire  data_out
  );

(* shreg_extract = "no", ASYNC_REG = "TRUE" *) reg  [C_NUM_SYNC_REGS-1:0]    sync1_r = {C_NUM_SYNC_REGS{1'b0}};

  //----------------------------------------------------------------------------
  // Synchronizer
  //----------------------------------------------------------------------------
  always @(posedge clk) begin
    sync1_r <= {sync1_r[C_NUM_SYNC_REGS-2:0], data_in};
  end

  assign data_out = sync1_r[C_NUM_SYNC_REGS-1];

endmodule
