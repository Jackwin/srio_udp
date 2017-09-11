
`define SEQ 32'h55bc55bc
`define ACK 32'hbc55bc55

module tcp_check
  #(
    parameter SRC_PORT = 16'h0400,
    parameter DES_PORT = 16'h00aa
    )
  (
   input 	clk,
   input 	reset,
   input [31:0] tcp_data_in,
   input 	tcp_data_valid,
   output reg 	tcp_error_out
   );

   localparam IDLE_s = 2'b00;
   localparam HEADER_s = 2'b01;
   localparam DATA_s = 2'b11;
   localparam END_s = 2'b10;
   
   reg [31:0] 	counter;
   reg [31:0] 	tcp_data_buf1, tcp_data_buf2;
   reg 		tcp_data_valid_r;
   reg [15:0] 	length;
   reg [15:0] 	checksum;
   reg [15:0] 	urg_ptr;
   
   reg [1:0] 	state;
   reg [2:0] 	cnt;

   always @(posedge clk) begin
      if (reset) begin
	 state <= IDLE_s;
	 tcp_data_buf1 <= 'h0;
	 tcp_data_buf2 <= 'h0;
	 tcp_error_out <= 1'b0;
	 counter <= 'h0;
	 length <= 'h0;
	 checksum <= 'h0;
	 urg_ptr <= 'h0;
	 cnt <= 'h0;
      end
      else begin
	 tcp_data_buf1 <= tcp_data_in;
	 tcp_data_buf2 <= tcp_data_buf1;
	 tcp_data_valid_r <= tcp_data_valid;
	 case (state)
	   IDLE_s: begin
	      if (tcp_data_valid) begin
		 state <= HEADER_s;
	      end
	      else begin
		 state <= IDLE_s;
	      end
	   end
	   HEADER_s: begin
	      case(cnt)
		3'h0: begin
		   if (tcp_data_buf1 == {SRC_PORT, DES_PORT} && tcp_data_valid_r) begin
		      tcp_error_out <= 1'b0;
		      cnt <= cnt + 'h1;
		   end
		   else begin
		      tcp_error_out <= 1'b1;
		      $display("Source Port Error");
		      $stop;
		   end
		end // case: 0
		3'h1: begin
		   if (tcp_data_buf1 == `SEQ && tcp_data_valid_r) begin
		      tcp_error_out <= 1'b0;
		      cnt <= cnt + 'h1;
		   end
		   else begin
		      tcp_error_out <= 1'b1;
		      $display("SEQ Error");
		      $stop;
		   end
		end // case: 3'h1
		3'h2: begin
		   if (tcp_data_buf1 == `ACK && tcp_data_valid_r) begin
		      tcp_error_out <= 1'b0;
		      cnt <= cnt + 'h1;
		   end
		   else begin
		      tcp_error_out <= 1'b1;
		      cnt <= cnt + 1'h1;
		      $display("ACK Error");
		      $stop;
		   end
		end // case: 3'h2
		3'h3: begin
		   cnt <= cnt + 'h1;
		   if (tcp_data_buf1[23:16] != 'h0) begin
		      $display("This is a ctrl package and the flag is %x", tcp_data_buf1[23:16]);
		   end
		   else begin
		     length <= (tcp_data_buf1 - 20) >> 2;
		   end
		end
		3'h4: begin
		   checksum <= tcp_data_buf1[31:16];
		   urg_ptr <= tcp_data_buf1[15:0];
		   state <= DATA_s;
		end
		default: begin
		   tcp_error_out <= 1'b0;
		end
	      endcase // case (cnt)
	   end
	   DATA_s: begin
	      if (tcp_data_valid_r) begin
		 counter <= counter + 'h1;
		 if (counter != tcp_data_buf1) begin
		    $display ("TCP Data Error");
		    tcp_error_out <= 1'b1;
		 end
		 else if(counter == (length - 1)) begin
		    $display ("TCP Data Passes Checking");
		    tcp_error_out <= 1'b0;
		 end
	      end 
	      else begin
		 counter <= 'h0;
		 state <= END_s;
	      end
	   end // case: Data_s
	   END_s: begin
	      state <= IDLE_s;
	   end
	   default:
	     state <= IDLE_s;
	 endcase // case (state)
      end // else: !if(reset)
   end // always @ (posedge clk)
endmodule // tcp_check

   
	   
		    
		   
		 
	      
		 
		 
	       
	      
		 
		 
	     
	 
	 
      
	   
	    
