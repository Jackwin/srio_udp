`timescale 1ns/1ps
`define clk_period 6.4
`define ram_data_width 64
`define ram_addr_width 10
`define ram_array 8
module ram_controller_sim();

   reg clk;
   reg reset;

   reg [`ram_data_width-1:0] data_gen;
   reg 			    data_gen_valid;
   reg [9:0] 		    data_gen_len;
   reg [2:0] 		    pack_seq_in = 3'h0;

   reg [2:0] 		    hash_pack_seq;
   wire  		    hash_hit;
   reg 			    hash_hit_r;
   
   reg [9:0] 		    hash_addr_offset;
   wire [`ram_data_width-1:0] rd_data;
   wire 		      rd_data_valid;
   
   
   initial begin
      clk = 1'b0;
      forever
	#(`clk_period/2) clk = ~clk;
   end

   initial begin
      reset = 1;
      #100 reset = 0;
   end

   int pack_num = 16;
   int data_cnt = 48;
   int hash_hit_pos = 35;
   
   
   int i,j;
   
   assign hash_hit = (j==hash_hit_pos || j == (hash_hit_pos + 3) || j == (hash_hit_pos + 12)) ? 1'b1 : 1'b0; // Generate hash hit signal
   always @(posedge clk) begin
      hash_hit_r <= hash_hit;
   end
   
   //assign hash_addr_offset = (hash_hit == 1'b1) ? ((hash_hit_pos -32) << 3) : 'h0;
   initial begin
      hash_addr_offset <= 0;
      #200;
      forever
	begin
	   @(posedge hash_hit)
	     hash_addr_offset <= (j - 32) <<3;
	end
   end

   always @(posedge clk or posedge reset) begin
      if (reset) begin
	 hash_pack_seq <= 'h0;
      end
      else if (j == 32) begin
	 hash_pack_seq <= pack_seq_in; // hash_pack_seq is 32 clocks delay than pack_seq
      end
   end
   
   initial begin
      #500;
      data_generation();
   end
   
   task data_generation();
      data_gen <= 'h0;
      data_gen_valid <= 1'b0;
      data_gen_len <= 'h0;
      pack_seq_in <= 0;
      for (i=0; i<pack_num; i++) begin
	 for (j=0; j<data_cnt; j++) begin
	    @(posedge clk);
	    data_gen_len <= data_cnt;
	    data_gen_valid <= 1'b1;
	    data_gen <= data_gen + 64'h1;
	 end
	 @(posedge clk);
	 data_gen_valid <= 1'b0;
	 pack_seq_in <= pack_seq_in + 3'h1;
	 data_cnt <= data_cnt + 1;
	 @(posedge clk);
	 @(posedge clk);
	 @(posedge clk);
	 @(posedge clk);
	 @(posedge clk);
      end // for (i=0; i<pack_num; i++)
   endtask; // data_generation
   

ram_controller 
ram_control_module(
		   .clk (clk),
		   .reset (reset),
		   .data_in (data_gen),
		   .data_valid_in (data_gen_valid),
		   .data_length_in (data_gen_len),
		   .pack_seq_in (pack_seq_in),
		   .hash_pack_seq_in (hash_pack_seq),
		   .hash_hit_in (hash_hit_r),
		   
		   .hash_addr_offset_in (hash_addr_offset), 
		   
		   .hash_pack_comp_out (),
		   .rd_data_valid_out (rd_data_valid),
		   .rd_data_out (rd_data)
    );

   
       
endmodule // ram_controller_sim
