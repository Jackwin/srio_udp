/*******************************************************************************************
 * Module: ram_controller
 * Project: Deep Package Filter in 10Gb/s Network
 * Description:
 * 1) The income packet is stored in 8 RAM array sequentially according to the pack_seq_in indicating which RAM to store the packet.
 * 2) All the signals related with hash hit begin with the prefix hash.
 * 3) If there are several hash hit in one packet, such as hash_addr_offset1, hash_addr_offset2, hash_addr_offset3, the readout data length is calculated based on the hash_addr_offset3(the last one) and hash_addr_offset1(the first one). Even though this method reduces the efficency when the difference between two hash hit is longer than 256 bytes, it does simplify the logics.
 * 4) If the difference between two hash hit is longer than 256 bytes in one packet, the readout data is more that desired, so rd_data_out_valid gives the indication.
 *******************************************************************************************/

module ram_controller
  #(
    parameter addr_width = 10,
    parameter data_width = 64,
    parameter ram_array = 8
    )
   (
    input 			clk,
    input 			reset,
    input [data_width-1:0] 	data_in,
    input 			data_valid_in,
    input [9:0] 		data_length_in,
    input [2:0] 		pack_seq_in, // The received package seqential number
    input [2:0] 		hash_pack_seq_in, // The package with the hash hit
    input 			hash_hit_in,
    input [9:0] 		hash_addr_offset_in, // The offset of the starting byte in the 

    output reg 			hash_pack_comp_out,// The readout package is integrated.
    output reg 			rd_data_valid_out, // 
    output reg [data_width-1:0] rd_data_out
    );

   localparam [3:0] rama_wr_idle_s = 'h0001;
   localparam [3:0] rama_wr_s = 'h0010;
   localparam [3:0] ramb_wr_idle_s = 'h0100;
   localparam [3:0] ramb_wr_s = 'h1000;

   localparam [3:0] rama_rd_idle_s = 'b0001;
   localparam [3:0] rama_rd_s = 'b0010;
   localparam [3:0] ramb_rd_idle_s = 'b0100;
   localparam [3:0] ramb_rd_s = 'b1000;

   localparam addr_cal_s0 = 4'b0001;
   localparam addr_cal_s1 = 4'b0010;
   localparam addr_cal_s2 = 4'b0100;
   localparam addr_cal_s3 = 4'b1000;


   reg [ram_array-1:0] 		ram_wr_ena;
   reg [addr_width-1:0] 	ram_wr_addr;
   reg [data_width-1:0] 	ram_wr_data[0:ram_array-1];

   reg [data_width-1:0] 	ram_rd_st_addr; // The starting read address in RAM
   reg [data_width-1:0] 	ram_rd_addr_cnt;   
   wire [9:0] 			ram_rd_end_addr;  // The total read length in the unit of 8-byte
   wire [data_width-1:0] 	ram_rd_data[0:ram_array-1];
   reg [addr_width-1:0] 	ram_rd_addr[0:ram_array-1];
   
   reg 				hash_hit_r0;
   
   //reg [9:0] 			hash_addr_offset; // Address offset in 8-byte
   reg [9:0] 			hash_addr_offset_r0;
   reg [9:0] 			hash_addr_offset_r1;
   wire [9:0] 			hash_addr_offset_dif;
   reg [9:0] 			hash_addr_offset_dif_r0;
   
   reg 				hash_next_pack_pulse;
   reg [2:0] 			hash_pack_seq_in_r0;

   reg [3:0] 			addr_cal_state;
   reg 				rd_data_valid;
   reg [1:0] 			counter;
   integer 			j;
   
   genvar 			i;
   generate
      for (i=0; i<8; i=i+1) begin
	 ram ram_module(.wr_clk(clk), .wr_ena(ram_wr_ena[i]),
			.wr_data(data_in), .wr_addr(ram_wr_addr),
			.rd_addr(ram_rd_addr[i]), .rd_data(ram_rd_data[i])
			);
      end
   endgenerate

   always @(posedge clk or posedge reset) begin
      if (reset) begin
	 ram_wr_addr <= 'h0;
      end
      else if (data_valid_in) begin
	 ram_wr_addr <= ram_wr_addr + 1'h1;
      end
      else
	ram_wr_addr <= 'h0;
   end
   // Write RAM Mux
   always @(*) begin
      case (pack_seq_in)
	3'h0: begin
	   ram_wr_ena[0] = data_valid_in;
	   ram_wr_ena[7:1] = 7'h0;
	end
	3'h1: begin
	   ram_wr_ena[1] = data_valid_in;
	   ram_wr_ena[7:2] = 6'h0;
	   ram_wr_ena[0] = 1'h0;
	end
	3'h2: begin
	   ram_wr_ena[2] = data_valid_in;
	   ram_wr_ena[7:3] = 5'h0;
	   ram_wr_ena[1:0] = 2'h0;
	end
	3'h3: begin
	   ram_wr_ena[3] = data_valid_in;
	   ram_wr_ena[7:4] = 4'h0;
	   ram_wr_ena[2:0] = 3'h0;
	end
	3'h4: begin
	   ram_wr_ena[4] = data_valid_in;
	   ram_wr_ena[7:5] = 3'h0;
	   ram_wr_ena[3:0] = 4'h0;
	end
	3'h5: begin
	   ram_wr_ena[5] = data_valid_in;
	   ram_wr_ena[7:6] = 2'h0;
	   ram_wr_ena[4:0] = 5'h0;
	end
	3'h6: begin
	   ram_wr_ena[6] = data_valid_in;
	   ram_wr_ena[7] = 1'h0;
	   ram_wr_ena[5:0] = 6'h0;
	end
	3'h7: begin
	   ram_wr_ena[7] = data_valid_in;
	   ram_wr_ena[6:0] = 7'h0;
	end
	default: begin
	   ram_wr_ena = 'h0;
	end
      endcase // case (package_seq)
   end // always @ (package_seq)

   /****************************************************************************************
    For every hash package, calculate the starting RAM read address and the total read length
    In every hash package, there may be several or even more hash hit, so the total read length is the difference between the last hash hit and the first hash hit pluses 32 (256/8).
    ****************************************************************************************/

   always @(posedge clk) begin // When hash_pack_seq is changing, generate hash_addr_offset reset signal
      hash_pack_seq_in_r0 <= hash_pack_seq_in;
      hash_next_pack_pulse <= !(hash_pack_seq_in ==hash_pack_seq_in_r0);
      hash_hit_r0 <= hash_hit_in;
   end

   always @(posedge clk or posedge reset) begin
      if (reset || hash_next_pack_pulse) begin
	 hash_addr_offset_r0 <= 'h0;
	 hash_addr_offset_dif_r0 <= 'h0;
      end
      else if (hash_hit_in) begin
	 hash_addr_offset_r0 <= hash_addr_offset_in >> 3; // Convert to 8-byte address

      end
      	 hash_addr_offset_dif_r0 <= hash_addr_offset_dif;
      //hash_addr_offset_dif = hash_addr_offset_r0 - (hash_addr_offset_in >>3);

   end
   assign hash_addr_offset_dif = hash_addr_offset_r0 - (hash_addr_offset_in >>3);
   assign ram_rd_end_addr = hash_addr_offset_dif + hash_addr_offset_dif_r0 + 10'h20 + ram_rd_st_addr;


   always @(posedge hash_hit_in) begin
      ram_rd_st_addr <= hash_addr_offset_in >> 3;
   end

   always @(posedge clk or posedge reset) begin
      if (reset) begin
	 addr_cal_state <= addr_cal_s0;
	 rd_data_valid <= 1'b0;
	 ram_rd_addr_cnt <= 'h0;
      end
      else begin
	 rd_data_valid <= 1'b0;
	 case (addr_cal_state)
	   addr_cal_s0: begin
	      counter <= 'h0;
	      if (hash_hit_in) begin
		 addr_cal_state <= addr_cal_s1;
	      end
	      else begin
		addr_cal_state <= addr_cal_s0;
	      end
	   end
	   addr_cal_s1: begin
	      ram_rd_addr_cnt <= ram_rd_st_addr;
	      addr_cal_state <= addr_cal_s2;
//	      if (&counter == 1'b1) begin
//		 addr_cal_state <= addr_cal_s2;
//	      end
//	      else begin
//		 counter <= counter + 2'b1;
//		 addr_cal_state <= addr_cal_s1;
//	      end
	   end
	   addr_cal_s2: begin
	      if (ram_rd_addr_cnt != ram_rd_end_addr) begin
		 ram_rd_addr_cnt <= ram_rd_addr_cnt + 10'h1;
		 rd_data_valid <= 1'b1;
	      end
	      else begin
		 ram_rd_addr_cnt <= ram_rd_addr_cnt;
		 rd_data_valid <= 1'b0;
	      end

	      if (hash_next_pack_pulse) begin    // New package comes
		 addr_cal_state <= addr_cal_s3;
		 hash_pack_comp_out <= (ram_rd_addr_cnt == ram_rd_end_addr); //Determine the read package integrity
	      end
	      else begin
		 addr_cal_state <= addr_cal_s2;
		 hash_pack_comp_out <= 1'b0;
	      end
	   end
	   
	   addr_cal_s3: begin
	      addr_cal_state <= addr_cal_s0;
	   end
	   default: begin
	      hash_pack_comp_out <= 1'b0;
	      rd_data_valid <= 1'b0;
	      addr_cal_state <= addr_cal_s0;
	   end
	 endcase // case (addr_cal_state)
      end // else: !if(reset)
   end // always @ (posedge clk or posedge reset)

   always @(posedge clk) begin
      rd_data_valid_out <= rd_data_valid;
   end
   
   
   /****************************************************************************************
    ****************************************************************************************/
	 
   always @(posedge clk or posedge reset) begin
      if (reset) begin
	 for (j=0; j< ram_array; j=j+1) begin
	    ram_rd_addr[j] <= 'h0;
	 end
	 
	 rd_data_out <= 'h0;
      end
      else begin
	 case (hash_pack_seq_in)
	   3'h0: begin
	      ram_rd_addr[0] <= ram_rd_addr_cnt;
	      rd_data_out <= ram_rd_data[0];
	   end
	   3'h1: begin
	      ram_rd_addr[1] <= ram_rd_addr_cnt;
	      rd_data_out <= ram_rd_data[1];
	   end
	   3'h2: begin
	      ram_rd_addr[2] <= ram_rd_addr_cnt;
	      rd_data_out <= ram_rd_data[2];
	   end
	   3'h3: begin
	      ram_rd_addr[3] <= ram_rd_addr_cnt;
	      rd_data_out <= ram_rd_data[3];
	   end
	   3'h4: begin
	      ram_rd_addr[4] <= ram_rd_addr_cnt;
	      rd_data_out <= ram_rd_data[4];
	   end
	   3'h5: begin
	      ram_rd_addr[5] <= ram_rd_addr_cnt;
	      rd_data_out <= ram_rd_data[5];
	   end
	   3'h6: begin
	      ram_rd_addr[6] <= ram_rd_addr_cnt;
	      rd_data_out <= ram_rd_data[6];
	   end
	   3'h7: begin
	      ram_rd_addr[7] <= ram_rd_addr_cnt;
	      rd_data_out <= ram_rd_data[7];
	   end
	   default: begin
	      rd_data_out <= 'h0;
	   end
	 endcase // case (hash_pack_seq_in)
      end // else: !if(reset)
   end // always @ (posedge clk or posedge reset)
	   
endmodule
	
	   
	   
	   
	   
	
	  
   
   
   

   
   
