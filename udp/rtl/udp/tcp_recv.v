/********************************************************************************************
 * Module: axi_packet_filter_recv_ip
 * Project: Packet filter in 10Gb/s network
 * Description:
 * 1) Parsing the packet to classify TCP(ICMP) or UDP
 * Reversion:
 * 1) Updated on 12/11/2016 
 *    1. Change the name from IP_recv.v to axi_packet_filter_recv_ip.v
 *    2. The data width is changed to 64-bit, compatible with AXI interface
 *    3. Output interface is changed to be AXI bus
 * *****************************************************************************************/


`define CWR 8'h80
`define ECE 8'h40
`define URG 8'h20
`define ACK 8'h10
`define PUSH 8'h08
`define RST 8'h04
`define SYN 8'h02
`define FIN 8'h01
module tcp_recv
  (
   input 	     clk,
   input 	     reset,
   input [31:0]      tcp_data_in,
   input 	     tcp_data_valid,

   output reg 	     option_valid,
   output reg [31:0] option_out,

   output reg 	     ctrl_data_valid_out,
   output reg [31:0] ctrl_data_out,

   output reg [31:0] tcp_data_out,
   output reg 	     tcp_data_valid_out	 
   );

   localparam WORD1_s = 3'b000;
   localparam WORD2_s = 3'b001;
   localparam WORD3_s = 3'b011;
   localparam WORD4_s = 3'b010;
   localparam WORD5_s = 3'b110;
   localparam OPTION_s = 3'b111;
   localparam CTRL_s = 3'b110;
   
   localparam DATA_s = 3'b100;
   
 
   
   reg [15:0] 	src_port;
   reg [15:0] 	dst_port;
   reg [31:0] 	seq_num;
   reg [31:0] 	ack_num;
   reg [3:0] 	data_offset;
   reg [8:0] 	flag;
   reg [8:0] 	win_size;
   reg [15:0] 	checksum;
   reg [7:0] 	urg_ptr;

   reg [31:0] 	option_data[7:0];
   

   reg [31:0] 	tcp_data_buf;
   reg [3:0] 	cnt;


   reg [2:0] 	state;

   reg [3:0] 	data_offset_len;
   reg [3:0] 	option_cnt;

   reg [2:0] 	ctrl_cnt;
   reg [3:0] 	ctrl_opt_cnt;
   
   

   always @ (posedge clk) begin
      if (reset) begin
	 src_port <= 'h0;
	 dst_port <= 'h0;
	 seq_num <= 'h0;
	 ack_num <= 'h0;
	 data_offset <= 'h0;
	 flag <= 'h0;
	 win_size <= 'h0;
	 checksum <= 'h0;
	 urg_ptr <= 'h0;

	 state <= WORD1_s;

	 option_valid <= 1'b0;
	 option_out <= 'h0;
	 option_cnt <= 'h0;

	 tcp_data_out <= 'h0;
	 tcp_data_valid_out <= 1'b0;

	 ctrl_cnt <= 'h0;
	 ctrl_data_out <= 'h0;
	 ctrl_data_valid_out <= 1'b0;
	 ctrl_opt_cnt <= 'h0;
	 cnt <= 'h0;
      end // if (reset)
      else begin
	 if (tcp_data_valid) begin
	 	    
	    case (state)
	      WORD1_s: begin
		 src_port <= tcp_data_in[31:16];
		 dst_port <= tcp_data_in[15:0];
		 state <= WORD2_s;
	      end
	      WORD2_: begin
		 seq_num <= tcp_data_in;
		 state <= WORD3_s;
	      end
	      WORD3_s: begin
		 ack_num <= tcp_data_in;
		 state <= WORD4_s;
	      end
	      WORD4_s: begin
		 data_offset <= tcp_data_in[31:28];
		 flag <= tcp_data_in[24:16];
		 win_size <= tcp_data_in[15:0];
		 state <= WORD5_s;
	      end
	      WORD5_s: begin
		 checksum <= tcp_data_in[31:16];
		 urg_ptr <= tcp_data_in[15:0];

		 if (data_offset > 5) begin
		    data_offset_len <= data_offset - 5 -1;
		    state <= OPTION_s;
		    
		 end
		 else if (data_offset == 5 && flag == 9'h0) begin
		    state <= DATA_s;
		 end
		 else if (data_offset == 5 && flag != 9'h0) begin
		    state <= CTRL_s;
		 end
	      end // case: WORD5_s
	      OPTION_s: begin
		 option_valid <= 1'b1;
		 option_out <= tcp_data_in;
		 option_data[option_cnt] <= tcp_data_;
		 if (option_cnt == data_offset_len) begin
		    state <= DATA_s;
		    option_cnt <= 'h0;
		 end
		 else begin
		    option_cnt <= option_cnt + 4'h1;
		 end
	      end // case: OPTION_s
	      CTRL_S: begin

		 case (ctrl_cnt)
		   0: begin
		      ctrl_data_out <= {src_port, dst_port};
		      ctrl_data_valid_out <= 1'b1;
		      ctrl_cnt <= ctrl_cnt + 'h1;
		   end
		   1: begin
		      ctrl_data_out <= seq_num;
		      ctrl_data_valid_out <= 1'b1;
		      ctrl_cnt <= ctrl_cnt + 'h1;
		   end
		   2: begin
		      ctrl_data_out <= ack_num;
		      ctrl_data_valid_out <= 1'b1;
		      ctrl_cnt <= ctrl_cnt + 'h1;
		   end
		   3: begin
		      ctrl_data_out <= {data_offset, 3'b000, flag, win_size};
		      ctrl_data_valid_out <= 1'b1;
		      ctrl_cnt <= ctrl_cnt + 'h1;
		   end
		   4: begin
		      ctrl_data_out <= {checksum, urg_ptr};
		      ctrl_data_valid_out <= 1'b1;
		      ctrl_cnt <= ctrl_cnt + 'h1;
		   end
		   5: begin
		      if (data_offset > 5) begin
			 if (ctrl_opt_cnt == data_offset_len) begin
			    state <= WORD1_s;
			    ctrl_data_valid_out <= 1'b0;
			    ctrl_opt_cnt <= ctrl_opt_cnt + 'h1;
			 end
			 else begin
			    ctrl_data_out <= option_data[ctrl_opt_cnt];
			    ctrl_opt_cnt <= ctrl_opt_cnt + 'h1;
			 end
		      end // if (data_offset > 5)
		      else begin
			 ctrl_data_valid_out <= 1'b0;
			 state <= WORD1_s;
			 end
		   end
		 endcase // case (ctrl_cnt)
	      end
	      DATA_s: begin
		 tcp_data_out <= tcp_data_in;
		 tcp_data_valid_out <= 1'b1;
	      end
	      default : begin
		 tcp_data_out <= 'h0;
		 tcp_data_valid_out <= 1'b0;
	      end
	    endcase // case (state)
	 end // if (tcp_data_valid)
	 else begin
	    state <= WORD1_s;
	    tcp_data_out <= 'h0;
	    tcp_data_valid_out <= 1'b1;
	 end // else: !if(tcp_data_valid)
      end // else: !if(reset)
   end // always @ (posedge clk)
   
	    
endmodule
	   
	    
	    
	      
		 
		    
		 
		 
	      
		 
	    
	 
   
