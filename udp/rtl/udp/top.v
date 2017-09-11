`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/16/2016 09:52:34 PM
// Design Name: 
// Module Name: top
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


module top
  (
   input 	 clk,
   input 	 reset,

   input 	 clk_64,
   input 	 reset_64,

   output [63:0] tdata_64,
   output [7:0]  tkeep_64,
   output 	 tvalid_64,
   output 	 tlast_64,

   input [47:0]  mac_addr,

   input 	 data_from_app_valid,
   input [31:0]  data_from_app,
   input [1:0] 	 op,
   input [31:0]  dest_ip_addr,
   input [15:0]  dest_port,
   input [15:0]  data_from_app_length,
   input [7:0] 	 tcp_ctrl_type,
  
   output [31:0] tdata,
   output [3:0]  tkeep,
   output 	 tvalid,
   output 	 tlast,
   output 	 tready

   );

   wire [31:0] 	 udp_data;
   wire 	 udp_data_valid;
   wire 	 tcp_error;
   wire 	 udp_error;
   
   send_top send_top_module
     (
      .clk(clk),
      .reset(reset),

      //inputs from application software to UDP stack
      .data_from_app_valid(data_from_app_valid),
      .data_from_app(data_from_app),
      .op(op),
      .dest_ip_addr(dest_ip_addr),
      .dest_port(dest_port),
      .data_from_app_length(data_from_app_length),
      .tcp_ctrl_type(tcp_ctrl_type),

      // output interface
      .tdata(tdata),
      .tkeep(tkeep),
      .tvalid(tvalid),
      .tlast(tlast)
      );

      axi_32to64 axi_32to64_module
     (
      .clk_32(clk),
      .reset_32(reset),
      .tdata_32(tdata),
      .tvalid_32(tvalid),
      .tlast_32(tlast),
      .tkeep_32(tkeep),
      .tready_32(),

      .clk_64(clk_64),
      .reset_64(reset_64),
      .tdata(tdata_64),
      .tvalid(tvalid_64),
      .tlast(tlast_64),
      .tkeep(tkeep_64),
      .tready(1'b0)
      );

   

   recv_top recv_top_module
     (
      .clk(clk),
      .reset(reset),
      .mac_addr(mac_addr),

      .data_in(tdata[31:0]),

      //.udp_data_out(udp_data),
      //.udp_data_valid(udp_data_valid)
      .tcp_error_out(tcp_error),
      .udp_error_out(udp_error)
      
      );
   

endmodule
