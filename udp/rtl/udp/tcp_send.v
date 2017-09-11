`timescale 1ps/1ps
/******************************************************************
 * Module: tcp_send
 * Project: Packet filter in 10Gb/s network
 * Author: Chunjie Wang
 * Description:
 * 1) Follow the TCP protocol to send data 
 ******************************************************************/
//TCP packet
//0                           15                             31
//-------------------------------------------------------------
// 16-bit source port          |     16-bit destination port  |
//-------------------------------------------------------------
//                        Sequential number                   |
//-------------------------------------------------------------
//                       Ack Number                           |
//-------------------------------------------------------------
// offset |Reseve(000)|NS|Flag |       Window SIze            |
//------------------------------------------------------------
// 16-bit Checksum 	       |   16-bit urgent pointer      |
//-------------------------------------------------------------
//                        Data                                |
//-------------------------------------------------------------

`define SOURCE_PORT 16'h0400
`define CHECKSUM 16'h0      // no checksum in udp
`define SEQ 32'h55bc55bc
`define ACK 32'hbc55bc55
`define WIN_SIZE 16'h0400
`define URG_PTR 16'h0


module tcp_send(
		input 		  clk,
		input 		  reset,
       // software app interface
		input [31:0] 	  data_in,
		input 		  data_in_valid,
		input [1:0] 	  op, //op=2 means sending TCP packet
		input [7:0] 	  ctrl_type, //control packet, such as SYNC, ACK, FIN and so on.
		input [31:0] 	  ip_addr_in,
		input [15:0] 	  dest_port,
		input [15:0] 	  length_in,
       //tcp data out
		output reg [31:0] ip_addr_out,
		output reg 	  tcp_data_valid_out,
		output reg [31:0] tcp_data_out,
		output reg [15:0] tcp_length_out
       );

   reg [31:0] 			  data_buf1, data_buf2;
   reg [31:0] 			  data_buf3, data_buf4, data_buf5;
   reg [2:0] 			  cnt, buf_cnt;
   always @(posedge clk or posedge reset) begin
      if (reset) begin
	 cnt <= 'h0;
	 buf_cnt <= 'h0;
	 ip_addr_out <= 32'b0;
	 tcp_data_valid_out <= 1'b0;
	 tcp_data_out <= 32'b0;
	 tcp_length_out <= 16'b0;
	 data_buf1 <= 32'b0;
	 data_buf2 <= 32'b0;
	 data_buf3 <= 32'h0;
	 data_buf4 <= 32'h0;
	 data_buf5 <= 32'h0;
      end
      else if ((data_in_valid && op == 'h2) || (ctrl_type != 'h0 && op == 'h2)) begin
	 case(cnt)
	   3'b000: begin
	      $display("Sending TCP packet starts.");
	      tcp_data_out <= {`SOURCE_PORT, dest_port};
	      tcp_data_valid_out <= 1'b1;
	      ip_addr_out <= ip_addr_in;
	      data_buf1 <= data_in;
	      buf_cnt <= buf_cnt + 'h1;
	      cnt <= cnt + 'h1;
	      tcp_length_out <= length_in + 'h14; // TCP header is 20-byte
	   end
	   3'b001: begin
	      tcp_data_out <= `SEQ;
	      tcp_data_valid_out <= 1'b1;
	      data_buf2 <= data_buf1;
	      data_buf1 <= data_in;
	      buf_cnt <= buf_cnt + 'h1;
	      cnt <= cnt + 'h1;
	   end
	   3'b010: begin
	      tcp_data_out <= `ACK;
	      tcp_data_valid_out <= 1'b1;
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= data_in;
	      buf_cnt <= buf_cnt + 'h1;
	      cnt <= cnt + 'h1;
	   end
	   3'b011: begin
	      if (ctrl_type == 'h0) begin
		 tcp_data_out <= {4'h5, 12'h000, length_in};
	      end
	      else begin
		 tcp_data_out <= {4'h4, 4'h0, ctrl_type,  `WIN_SIZE};
	      end
	      tcp_data_valid_out <= 1'b1;
	      data_buf4 <= data_buf3;
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= data_in;
	      buf_cnt <= buf_cnt + 'h1;
	      cnt <= cnt + 'h1;
	   end
	   3'b100: begin
	      tcp_data_out <= {`CHECKSUM, `URG_PTR};
	      tcp_data_valid_out <= 1'b1;
	      data_buf5 <= data_buf4;
	      data_buf4 <= data_buf3;
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= data_in;
	      buf_cnt <= buf_cnt + 'h1;
	      cnt <= cnt + 'h1;
	   end
	   3'b101: begin
	      tcp_data_out <= data_buf5;
	      tcp_data_valid_out <= 1'b1;
	      data_buf5 <= data_buf4;
	      data_buf4 <= data_buf3;
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= data_in;
	   end
	   default: cnt <= 'h0;
	 endcase // case (cnt)
      end // if (data_in_valid && op == 'h2)
      else if (!data_in_valid && op == 'h2) begin
	 if (buf_cnt != 3'h0) begin
	    tcp_data_valid_out <= 1'b1;
	    tcp_data_out <= data_buf5;
	    data_buf5 <= data_buf4;
	    data_buf4 <= data_buf3;
	    data_buf3 <= data_buf2;
	    data_buf2 <= data_buf1;
	    data_buf1 <= data_in;
	    buf_cnt <= buf_cnt - 'h1;
	    cnt <= 2'h0;
	 end
	 else begin
//	    $display("Sending TCP packet ends.");
	    
	    tcp_data_valid_out <= 1'b0;
	    cnt <= 'h0;
	 end // else: !if(buf_cnt != 3'h0)
      end // if (!data_in_valid && op == 'h2)
      else begin
	 tcp_data_valid_out <= 1'b0;
	 cnt <= 'h0;
      end // else: !if(!data_in_valid && op == 'h2)
   end // always @ (posedge clk)
endmodule // input

