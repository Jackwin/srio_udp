module udp_check
  #(
    parameter SRC_PORT = 16'h0400,
    parameter DES_PORT = 16'h00aa
    )
  (
   input 	clk,
   input 	reset,
   input [31:0] udp_data_in,
   input 	udp_data_valid,
   output reg 	udp_error_out
   );

   localparam IDLE_s = 2'b00;
   localparam HEADER_s = 2'b01;
   localparam DATA_s = 2'b10;
   
   reg [31:0] 	counter;
   reg [31:0] 	udp_data_buf1, udp_data_buf2;
   reg 		udp_data_valid_r;
   reg [15:0] 	length;
   reg [15:0] 	checksum;
   
   reg [1:0] 	state;


   always @(posedge clk) begin
      if (reset) begin
	 state <= IDLE_s;
	 udp_data_buf1 <= 'h0;
	 udp_data_buf2 <= 'h0;
	 udp_error_out <= 1'b0;
	 counter <= 'h0;
	 length <= 'h0;
	 checksum <= 'h0;
      end
      else begin
	 udp_data_buf1 <= udp_data_in;
	 udp_data_buf2 <= udp_data_buf1;
	 udp_data_valid_r <= udp_data_valid;
	 case (state)
	   IDLE_s: begin
	      if (udp_data_valid) begin
		 state <= HEADER_s;
	      end
	      else begin
		 state <= IDLE_s;
	      end
	   end
	   HEADER_s: begin
	      if (udp_data_buf1 == {SRC_PORT, DES_PORT} && udp_data_valid_r) begin
		 state <= DATA_s;
	      end
	      else begin
		 $display ("Source Port Error!");
		 state <= IDLE_s;
		 udp_error_out <= 1'b1;
	      end
	      length <= (udp_data_in[31:16] - 8) >> 2; // Minus the header'length
	      checksum <= udp_data_in[15:0];
	   end
	   DATA_s: begin
	      if (udp_data_valid) begin
		 counter <= counter + 'h1;
		 if (counter != udp_data_in) begin
		    $display ("UDP Data Error");
		    udp_error_out <= 1'b1;
		 end
		 else if(counter == (length - 1)) begin
		    $display ("UDP Data Passes Checking");
		    udp_error_out <= 1'b0;
		 end
	      end // if (udp_data_valid)
	      else begin
		 counter <= 'h0;
		 state <= IDLE_s;
	      end
	   end // case: Data_s
	   endcase // case (state)
	 end // else: !if(reset)
   end // always @ (posedge clk)
endmodule // udp_check

   
	   
		    
		   
		 
	      
		 
		 
	       
	      
		 
		 
	     
	 
	 
      
	   
	    
