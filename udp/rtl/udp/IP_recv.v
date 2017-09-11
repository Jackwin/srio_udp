
`define IP_ADDRR 32'hc0a80102
`define VERS 31:28
`define HLEN 27:24
`define TLEN 15:0

`define TCP_Pro 8'h06
`define UDP_Pro 8'h11
`define ICMP_Pro 8'h01

module IP_recv
  (
   input 	     clk,
   input 	     reset,
   input 	     ip_data_valid,
   input [7:0]      ip_data,


   output reg 	     options_out,
   output reg 	     tcp_valid_out,
   output reg [31:0] tcp_data_out,
   output reg 	     udp_valid_out,
   output reg [31:0] udp_data_out
   );

   reg [15:0] 	     cnt;
   reg [16:0] 	     tmp_accum1, tmp_accum2, tmp_accum3;
   reg [15:0] 	     accum1, accum2, final_accum,checksum, head_length, full_length, data_length;
   reg [7:0] 	     ip_data_buffer;
   reg [7:0] 	     data_buf1, data_buf2, data_buf3, data_buf4;
   reg [7:0] 	     data_buf5, data_buf6;

   reg 		     options, start_data;
   reg [7:0] 	     protocal;
   reg [2:0] 	     bufcnt;


   always @(posedge clk) begin
      if (reset) begin
	 cnt <= 16'b0;
	 bufcnt <= 'h6;
	 udp_data_out <= 32'h0;
	 udp_valid_out <= 1'b0;
	 tcp_data_out <= 32'h0;
	 tcp_valid_out <= 1'b0;
	 ip_data_buffer <= 32'h0;
	 options <= 1'b0;
	 data_length <= 16'h0;
	 start_data <= 1'b0;
	 protocal <= 8'h0;
	 data_buf1 <= 'h0;
	 data_buf2 <= 'h0;
	 data_buf3 <= 'h0;
	 data_buf4 <= 'h0;
	 data_buf5 <= 'h0;
	 data_buf6 <= 'h0;

	 tmp_accum1 <= 'h0;
	 tmp_accum2 <= 'h0;
	 tmp_accum3 <= 'h0;
	 accum1 <= 'h0;
	 accum2 <= 'h0;
	 final_accum <= 'h0;
	 checksum <= 'h0;
	 head_length <= 'h0;
	 full_length <= 'h0;

	 options_out <= 1'b0;

      end
      else if (ip_data_valid) begin
	 case (cnt)
	   0: begin
	      bufcnt <= 'h6;
	      udp_valid_out <= 1'b0;
	      accum1 <= ip_data[15:0];
	      accum2 <= ip_data[31:16];
	      head_length <= ip_data[`HLEN] << 2;
	      full_length <= ip_data[`TLEN];
	      if (ip_data[`HLEN] == 4'd5) begin
		 options <= 1'b0;
	      end
	      else if (ip_data[`HLEN] > 4'd5) begin
		 options <= 1'b1;
	      end
	      cnt <= cnt + 16'b1;
	   end // case: 0
	   1: begin
	      tmp_accum1 <= (accum1 + ip_data[15:0]);
	      tmp_accum2 <= (accum2 + ip_data[31:16]);
	      data_length <= full_length - head_length;
	      cnt <= cnt + 16'b1;
	      start_data <= 1'b1;
	   end

	   2: begin
	      accum1 <= tmp_accum1[15:0] + tmp_accum1[16];
	      accum2 <= tmp_accum2[15:0] + tmp_accum2[16];
	      data_buf1 <= ip_data;
	      checksum <= ip_data[15:0];
	      protocal <= ip_data[23:16];

	      data_length <= data_length >> 2; // word length
	      cnt <= cnt + 16'b1;

	   end
	   3: begin
	      tmp_accum2 <= (accum2 + data_buf1[31:16]);
	      accum1 <= accum1; // Jump checksum
	      data_buf1 <= ip_data;  // Source IP
	      cnt <= cnt + 'h1;
	   end
	   4: begin
	      accum2 <= tmp_accum2[15:0] + tmp_accum2[16];
	      accum1 <= tmp_accum1[15:0] + tmp_accum1[16];
	      data_buf2 <= data_buf1;
	      data_buf1 <= ip_data;  // Destination IP
	      cnt <= cnt + 16'b1;
	   end

	   5: begin
	      tmp_accum1 <= (accum1 + data_buf2[15:0]);
	      tmp_accum2 <= (accum2 + data_buf2[31:16]);
	      data_buf2 <= data_buf1;
	      data_buf1 <= ip_data;  // 1st data
	      cnt <= cnt + 16'b1;
	   end
	   6: begin
	      accum1 <= tmp_accum1[15:0] + tmp_accum1[16];
	      accum2 <= tmp_accum2[15:0] + tmp_accum2[16];
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= ip_data;  // 2nd data
	      cnt <= cnt + 16'b1;
	   end
	   7: begin
	      tmp_accum1 <= (accum1 + data_buf3[15:0]);
	      tmp_accum2 <= (accum2 + data_buf3[31:16]);
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= ip_data;  // 3nd data
	      cnt <= cnt + 16'b1;
	   end
	   8: begin
	      accum1 <= tmp_accum1[15:0] + tmp_accum1[16];
	      accum2 <= tmp_accum2[15:0] + tmp_accum2[16];
	      data_buf4 <= data_buf3;
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= ip_data;  // 4nd data
	      cnt <= cnt + 16'b1;
	   end
	   9: begin
	      if (options == 1'b0) begin
		 tmp_accum3 <= accum1 + accum2;

		 if (data_length == 'h0) begin
		    $display("data length is 0!!");
		 end
		 else begin
		    data_length <= data_length - 'h1;
		    $display ("Data length is %d words(32-bit)", data_length);

		 end
	      end
	      else begin
		 $dispaly ("Option is included.");
		 options_out <= 1'b1;

	      end // else: !if(options == 1'b0)

	      data_buf5 <= data_buf4;
	      data_buf4 <= data_buf3;
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= ip_data;  // 5nd data
	      cnt <= cnt + 16'b1;
	   end
	   10: begin
	      options_out <= 1'b0;
	      final_accum <= tmp_accum3[15:0] + tmp_accum3[16];
	      data_buf6 <= data_buf5;
	      data_buf5 <= data_buf4;
	      data_buf4 <= data_buf3;
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= ip_data;  // 6nd data
	      cnt <= cnt + 16'b1;
	   end
	   11: begin
	      if (final_accum != ~checksum) begin
		 $display ("IP header checksum error!");
	      end
	      if (protocal == `UDP_Pro) begin
		 udp_valid_out <= 1'b1;
		 udp_data_out <= data_buf6;
	      end // if (protocal == `UDP_Pro)
	      else if (protocal == `TCP_Pro) begin
		 tcp_valid_out <= 1'b1;
		 tcp_data_out <= data_buf6;
	      end
	      data_buf6 <= data_buf5;
	      data_buf5 <= data_buf4;
	      data_buf4 <= data_buf3;
	      data_buf3 <= data_buf2;
	      data_buf2 <= data_buf1;
	      data_buf1 <= ip_data;
	      data_length <= data_length - 16'h0001;
	   end
	   default: cnt <= 16'h0;
	 endcase
      end
      else if (~ip_data_valid) begin
	 if ((data_length != 16'h0) && (start_data == 1'b1)) begin
	    if (bufcnt != 'h0) begin
	       bufcnt <= bufcnt - 'h1;
	       case (protocal)
		 `UDP_Pro: begin
		    udp_valid_out <= 1'b1;
		    udp_data_out <= data_buf6;
		 end
		 `TCP_Pro: begin
		    tcp_valid_out <= 1'b1;
		    tcp_data_out <= data_buf6;
		 end
		 default: begin
		    tcp_valid_out <= 1'b0;
		    tcp_data_out <= 'h0;
		    udp_valid_out <= 1'b0;
		    udp_data_out <= 'h0;
		 end
	       endcase // case (protocal)
	       cnt <= 16'b0;
	       data_buf6 <= data_buf5;
	       data_buf5 <= data_buf4;
	       data_buf4 <= data_buf3;
	       data_buf3 <= data_buf2;
	       data_buf2 <= data_buf1;
	       data_buf1 <= ip_data;
	    end // if (bufcnt != 'h0)
	    else begin
	       udp_valid_out <= 1'b0;
	       tcp_valid_out <= 1'b0;
	       start_data <= 1'b0;
//	       case (protocal)
//		 `TCP_Pro: begin
//		    udp_valid_out <= 1'b0;
//		 end
//		 `UDP_Pro: begin
//		    tcp_valid_out <= 1'b0;
//		 end
//		 default: begin
//		    udp_valid_out <= 1'b0;
//		    tcp_valid_out <= 1'b0;
//		 end
//	       endcase // case (protocal)
	    end // else: !if(bufcnt != 'h0)

	 end
	 else if ((data_length == 16'h0) && (start_data == 1'b0)) begin
	    udp_valid_out <= 1'b0;
	    tcp_valid_out <= 1'b0;
	 end
	 else if (data_length != 16'h0) begin
	    udp_valid_out <= 1'b0;
	    tcp_valid_out <= 1'b0;
	 end
      end // if (~ip_data_valid)
   end // always @ (posedge clk)


endmodule
