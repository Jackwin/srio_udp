
`timescale 1ns/10ps

module axis32to8 (
    input           clk_32,
    input           reset_32,
    input [31:0]    axis_tdata_in,
    input           axis_tvalid_in,
    input [3:0]     axis_tkeep_in,
    input           axis_tlast_in,
    output          axis_tready_out,

    input           clk_8,
    input           reset_8,
    input           axis_tready_in,
    output [7:0]    axis_tdata_out,
    output          axis_tvalid_out,
    output          axis_tlast_out
);

wire                fifo_empty, fifo_full;
wire                fifo_wr_ena, fifo_rd_ena;
wire [(8+3)*4-1:0]  fifo_din;
wire [8+3-1:0]      fifo_dout;
wire [(8+3)-1:0]    fifo_din3, fifo_din2, fifo_din1, fifo_din0;
wire                fifo_din3_last, fifo_din2_last, fifo_din1_last, fifo_din0_last;
reg                 fifo_dout_valid;
assign axis_tready_out = ~fifo_full;
assign fifo_wr_ena = axis_tvalid_in;
assign fifo_rd_ena = axis_tready_in && ~fifo_empty;
assign fifo_din3_last = (axis_tlast_in && axis_tkeep_in[3:0] == 4'b1000) ? 1'b1 : 1'b0;
assign fifo_din2_last = (axis_tlast_in && axis_tkeep_in[2:0] == 3'b100) ? 1'b1 : 1'b0;
assign fifo_din1_last = (axis_tlast_in && axis_tkeep_in[1:0] == 2'b10) ? 1'b1 : 1'b0;
assign fifo_din0_last = (axis_tlast_in && axis_tkeep_in[0] == 1'b1) ? 1'b1 : 1'b0;

assign fifo_din3 = {axis_tdata_in[31:24], axis_tkeep_in[3], axis_tvalid_in, fifo_din3_last};
assign fifo_din2 = {axis_tdata_in[23:16], axis_tkeep_in[2], axis_tvalid_in, fifo_din2_last};
assign fifo_din1 = {axis_tdata_in[15:8], axis_tkeep_in[1], axis_tvalid_in, fifo_din1_last};
assign fifo_din0 = {axis_tdata_in[7:0], axis_tkeep_in[0], axis_tvalid_in, fifo_din0_last};
assign fifo_din = {fifo_din3, fifo_din2, fifo_din1, fifo_din0};

always @(posedge clk_8 or negedge reset_8) begin
    if (reset_8) begin
        fifo_dout_valid <= 1'b0;
    end
    else begin
        fifo_dout_valid <= fifo_rd_ena;
    end
end

assign axis_tdata_out = fifo_dout[10:3];
assign axis_tvalid_out = fifo_dout_valid ? (fifo_dout[2] & fifo_dout[1]) : 1'b0;
assign axis_tlast_out = fifo_dout_valid ? fifo_dout[0] : 1'b0;

// MSB pop out first
fifo_44in_11out fifo_i (
  .rst(reset_8),        // input wire rst
  .wr_clk(clk_32),  // input wire wr_clk
  .rd_clk(clk_8),  // input wire rd_clk
  .din(fifo_din),        // input wire [31 : 0] din
  .wr_en(fifo_wr_ena),    // input wire wr_en
  .rd_en(fifo_rd_ena),    // input wire rd_en
  .dout(fifo_dout),      // output wire [7 : 0] dout
  .full(fifo_full),      // output wire full
  .empty(fifo_empty)    // output wire empty
);

endmodule // axis32to8

