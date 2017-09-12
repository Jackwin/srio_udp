`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/14/2016 03:27:35 PM
// Design Name: 
// Module Name: send_top_tb
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


`define clk_period 6.4
`define send_unit 80*6.4

module send_top_tb(

    );

   reg clk;
   reg reset;

   reg clk_64;
   reg reset_64;
   

   // udp data
   localparam DEST_MAC = 48'hdd0504030201;
   localparam SRC_MAC = 48'h55ffeebbccaa;
   localparam SRC_IP = 32'hc0a82505; //    192.168.37.5
   localparam DEST_IP = 32'hc0a8250d; // 192.168.37.13
   localparam UDP_DATA_LENGTH = 16'h50;
   localparam TCP_DATA_LENGTH = 16'h70;
   
   reg [31:0] data_from_app;
   reg 	      data_from_app_valid;
   reg [15:0] data_from_app_length;
   reg [1:0]  op;
   reg [7:0]  tcp_ctrl_type;
   
   //AXI stream
   wire [31:0] tdata;
   wire [3:0]  tkeep;
   wire        tvalid;
   wire        tlast;

   wire [63:0] tdata_64;
   wire [7:0]  tkeep_64;
   wire        tvalid_64;
   wire        tlast_64;

   top top_module
     (
      .clk (clk),
      .reset (reset),

      .clk_64(clk_64),
      .reset_64(reset_64),
      .mac_addr(DEST_MAC),
      
      .data_from_app(data_from_app),
      .data_from_app_valid(data_from_app_valid),
      .op(op),
      .data_from_app_length(data_from_app_length),
      .tcp_ctrl_type(tcp_ctrl_type),
      .dest_port(16'haa),
      .dest_ip_addr(DEST_IP),

      .tdata_64(tdata_64),
      .tkeep_64(tkeep_64),
      .tvalid_64(tvalid_64),
      .tlast_64(tlast_64),
      
      .tdata(tdata),
      .tkeep(tkeep),
      .tvalid(tvalid),
      .tlast(tlast)
      );

   
   initial begin
      clk = 0;
      forever
	#(`clk_period/2) clk = ~clk;
   end

   initial begin
      reset = 1;
      forever
	#100 reset <= 0;
   end

   initial begin
      clk_64 = 0;
      forever
	#(`clk_period) clk_64 = ~clk_64;
   end

   initial begin
      reset_64 = 1;
      forever
	#100 reset_64 <= 0;
   end

   initial begin
      data_from_app_valid <= 1'b0;
      data_from_app_length <= 16'h0;
      op <= 'h0;
      tcp_ctrl_type <= 'h0;
      #500;
      udp_data_gen();
      #1000;
      arp_data_gen();
      #500;
      tcp_data_gen();
   end
   
   // Generate udp data
   task udp_data_gen;
      integer 	    i;
      
      begin
	 for (i = 0; i < UDP_DATA_LENGTH; i = i+1) begin
	    @ (posedge clk);
	    data_from_app <= i;
	    data_from_app_valid <= 1'b1;
	    op <= 'h1;
	    data_from_app_length <= UDP_DATA_LENGTH << 2; // byte length
	 end
	 @ (posedge clk);
	 data_from_app_valid <= 1'b0;
	 @ (posedge clk);
	 @ (posedge clk);
	 @ (posedge clk);
	 op <= 'h0;
      end
      
   endtask // if

   task tcp_data_gen;
      integer i;
      begin
	 for (i = 0; i < TCP_DATA_LENGTH; i = i+1) begin
	    @ (posedge clk);
	    data_from_app <= i;
	    data_from_app_valid <= 1'b1;
	    op <= 'h2;
	    tcp_ctrl_type <= 'h0;
	    data_from_app_length <= TCP_DATA_LENGTH << 2; // byte length
	 end
	 @ (posedge clk);
	 data_from_app_valid <= 1'b0;
	 @ (posedge clk);
	 @ (posedge clk);
	 @ (posedge clk);
	 @ (posedge clk);
	 @ (posedge clk);
	 @ (posedge clk);
	 @ (posedge clk);
	 op <= 'h0;
      end
      
   endtask
   
   // Generate arp data
   task arp_data_gen;
      
      begin
	 @(posedge clk);
	 data_from_app <= 'h00010006; //arp req
	 data_from_app_valid <= 1'b1;
	 @(posedge clk) data_from_app <= 'h00060004;
	 @(posedge clk) data_from_app <= SRC_MAC[47:16];
	 @(posedge clk) data_from_app <= {SRC_MAC[15:0],SRC_IP[31:16]};
	 @(posedge clk) data_from_app <= {SRC_IP[15:0],DEST_MAC[47:32]};
	 @(posedge clk) data_from_app <= DEST_MAC[31:0];
	 @(posedge clk) data_from_app <= DEST_IP;
	 @(posedge clk) data_from_app_valid <= 1'b0;
	 
      end
   endtask //
         
   
   
   
endmodule
