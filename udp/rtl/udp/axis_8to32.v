`timescale 1ns/1ps

module axis_8to32 (
    input           clk_8,
    input           reset_8,

    input [7:0]     axis_tdata_in,
    input           axis_tvalid_in,
    input           axis_tlast_in,
    output          axis_tready_out,

    input           clk_32,
    input           reset_32,
    output [31:0]   axis_tdata_out,
    output [3:0]    axis_tkeep_out,
    output          axis_tvalid_out,
    output reg      axis_tfirst_out,
    output          axis_tlast_out,
    input           axis_tready_in
);

reg [7:0]           data_buf3, data_buf2, data_buf1, data_buf0;
wire [31:0]         data_4bytes;
reg [1:0]           byte_cnt;

wire [32+4+1+1-1:0] fifo_din, fifo_dout;
wire                fifo_wr_ena, fifo_rd_ena;
wire                fifo_empty, fifo_full;
wire                fifo_wr_clk, fifo_rd_clk;
reg [3:0]           data_keep = 4'b0000;
reg                 data_last = 1'b0;
reg                 data_valid = 1'b0;

reg                 fifo_dout_valid;

assign fifo_wr_clk = clk_8;
assign fifo_rd_clk = clk_32;
assign data_4bytes = {data_buf2, data_buf1, data_buf0, axis_tdata_in};
assign fifo_din = {data_4bytes, data_keep, data_last, data_valid};
assign fifo_wr_ena = data_valid;
assign axis_tready_out = ~fifo_full;
assign fifo_rd_ena = (axis_tready_in && ~fifo_empty) ? 1'b1 : 1'b0;

assign axis_tdata_out = fifo_dout[37:6];
//assign {axis_tkeep_out, axis_tlast_out, axis_tvalid_out} = fifo_dout_valid ? fifo_dout[5:0] : {axis_tkeep_out, axis_tlast_out, axis_tvalid_out};
assign axis_tvalid_out = fifo_dout_valid;
assign {axis_tkeep_out, axis_tlast_out} = fifo_dout_valid ? fifo_dout[5:1] : 'h0;


always @(posedge clk_32) begin
    if (reset_32) begin
        fifo_dout_valid <= 1'b0;
        axis_tfirst_out <= 1'b1;
    end
    else begin
        fifo_dout_valid <= fifo_rd_ena;
        if (axis_tvalid_out) begin
            axis_tfirst_out <= 1'b0;
        end
        else if (axis_tlast_out) begin
            axis_tfirst_out <= 1'b1;
        end
    end
end

always @(posedge clk_8) begin
    if (reset_8) begin
        data_buf3 <= 'h0;
        data_buf2 <= 'h0;
        data_buf1 <= 'h0;
        data_buf0 <= 'h0;
    end
    else if (axis_tvalid_in) begin
        data_buf3 <= data_buf2;
        data_buf2 <= data_buf1;
        data_buf1 <= data_buf0;
        data_buf0 <= axis_tdata_in;
    end
    else begin
        data_buf3 <= data_buf3;
        data_buf2 <= data_buf2;
        data_buf1 <= data_buf1;
        data_buf0 <= data_buf0;
    end
end

always @(posedge clk_8) begin
    if (reset_8) begin
        byte_cnt <= 'h0;
    end
    else begin
        if (axis_tlast_in) begin
            byte_cnt <= 'h0;
        end
        else if (axis_tvalid_in) begin
            byte_cnt <= byte_cnt + 1'b1;
        end
    end
end

always @(*) begin
    case(byte_cnt)
        2'd0: begin
            if (axis_tvalid_in && axis_tlast_in) begin
                data_keep = 4'b0001;
                data_last = 1'b1;
                data_valid = 1'b1;
            end
            else begin
                data_keep = 4'b0000;
                data_last = 1'b0;
                data_valid = 1'b0;
            end
        end
        2'd1: begin
            if (axis_tvalid_in && axis_tlast_in) begin
                data_keep = 4'b0011;
                data_last = 1'b1;
                data_valid = 1'b1;
            end
            else begin
                data_keep = 4'b0000;
                data_last = 1'b0;
                data_valid = 1'b0;
            end
        end
        3'd2: begin
            if (axis_tvalid_in && axis_tlast_in) begin
                data_keep = 4'b0111;
                data_last = 1'b1;
                data_valid = 1'b1;
            end
            else begin
                data_keep = 4'b0000;
                data_last = 1'b0;
                data_valid = 1'b0;
            end
        end
        3'd3: begin
            if (axis_tvalid_in && !axis_tlast_in) begin
                data_keep = 4'b1111;
                data_last = 1'b0;
                data_valid = 1'b1;
            end
            else if (axis_tvalid_in && axis_tlast_in) begin
                data_keep = 4'b1111;
                data_last = 1'b1;
                data_valid = 1'b1;
            end
            else begin
                data_keep = 4'b0000;
                data_last = 1'b0;
                data_valid = 1'b0;
            end
        end
    endcase // byte_cnt
end

fifo_38inx512 fifo_38inx512_i (
  .rst(reset_8),        // input wire rst
  .wr_clk(fifo_wr_clk),  // input wire wr_clk
  .rd_clk(fifo_rd_clk),  // input wire rd_clk
  .din(fifo_din),        // input wire [37 : 0] din
  .wr_en(fifo_wr_ena),    // input wire wr_en
  .rd_en(fifo_rd_ena),    // input wire rd_en
  .dout(fifo_dout),      // output wire [37 : 0] dout
  .full(fifo_full),      // output wire full
  .empty(fifo_empty)    // output wire empty
);


endmodule