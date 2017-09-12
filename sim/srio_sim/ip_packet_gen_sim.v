`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/10/2016 09:58:05 AM
// Design Name: 
// Module Name: ip_packet_gen_sim
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


module ip_packet_gen_sim(

    );
   reg clk_32;
   reg reset_32;
   reg enable_pat_gen;
   reg [1:0] op;
   reg [7:0] tcp_ctrl_type;
   reg [31:0] dest_ip_addr = 32'hddccbbaa;
   reg [15:0] dest_port = 32'd1024;

   reg 	      aclk;
   reg 	      areset;

   wire [63:0] tdata;
   wire [7:0]  tkeep;
   wire        tvalid;
   wire        tlast;

   initial begin
      clk_32 = 1'b0;
      forever
	#5 clk_32 = ~clk_32;
   end

   initial begin
      reset_32 = 1'b1;
      #100 reset_32 = 1'b0;
   end

   initial begin
      aclk = 1'b0;
      forever
	#10 aclk = ~aclk;
   end

   initial begin
      areset = 1'b1;
      #100 areset = 1'b0;
   end
   initial begin
      op = 'h0;
      enable_pat_gen = 1'b0;
      tcp_ctrl_type = 'h0;
      #500;
      @(posedge clk_32);
      op = 'h1;
      enable_pat_gen = 1'b1;
      @(posedge clk_32);
      @(posedge clk_32);
      op = 'h0;
      enable_pat_gen = 1'b0;
   end // initial begin
   
      
   ip_packet_gen ip_packet_gen_module
  (

   // IP signals
   .clk_32(clk_32),
   .reset_32(reset_32),
   .enable_ip_data_gen(enable_pat_gen),
   .tcp_ctrl_type(tcp_ctrl_type),
   .dest_ip_addr(dest_ip_addr),
   .dest_port(dest_port),

   .aclk(aclk),
   .areset(areset),

   .tdata(tdata),
   .tkeep(tkeep),
   .tvalid(tvalid),
   .tlast(tlast),
   .tready(1'b1)
    );

endmodule
