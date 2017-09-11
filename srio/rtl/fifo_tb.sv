`timescale 1ps/1ns
module fifo_tb (

	
);

	reg clk;   // Clock
	reg clk_en; // Clock Enable
	reg rst_n;  // Asynchronous reset active low

	reg data_gen_ena;
	reg [74:0] data_gen;

	wire fifo_empty, fifo_full;
	wire fifo_rd_ena,fifo_wr_ena;
	wire [74:0] fifo_dout;
	wire [8:0] fifo_data_cnt;

initial begin
	clk = 1'b0;
	forever
	#5 clk = ~clk;
end

initial begin
	rst_n = 1'b1;
	#140;
	rst_n = 1'b0;
	#50;
	rst_n = 1'b1;
end

initial begin
	data_gen_ena = 1'b0;
	#300;
	data_gen_ena = 1'b1;
	#500;
	data_gen_ena = 1'b0;
end

always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		data_gen <= 'h0;
	end
	else begin
		if (data_gen_ena) begin
			data_gen <= data_gen + 'h1;
		end
		else begin
			data_gen <= data_gen;
		end
	end
end

assign fifo_rd_ena = ~fifo_empty;
assign fifo_wr_ena = data_gen_ena;


fifo_75x512 user_data_fifo (
  .clk(clk),                // input wire clk
  .srst(~rst_n),              // input wire srst
  .din(data_gen),                // input wire [65 : 0] din
  .wr_en(fifo_wr_ena),            // input wire wr_en
  .rd_en(fifo_rd_ena),            // input wire rd_en
  .dout(fifo_dout),              // output wire [65 : 0] dout
  .full(fifo_full),              // output wire full
  .empty(fifo_empty),            // output wire empty
  .data_count(fifo_data_cnt)  // output wire [8 : 0] data_count
);

	
endmodule