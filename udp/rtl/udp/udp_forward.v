`timescale 1ns/1ps
/*
Return the received UPD packets without any further processing.
*/

module udp_forward (
    input               clk,
    input               reset,

    input [7:0]         udp_axis_tdata_in,
    input               udp_axis_tvalid_in,
    input               udp_axis_tlast_in,
    output              udp_axis_tready_out,

    input               clk_32,
    input               reset_32,
    output [31:0]       udp_axis_tdata_out,
    output              udp_axis_tvalid_out,
    output              udp_axis_tfirst_out,
    output [3:0]        udp_axis_tkeep_out,
    output              udp_axis_tlast_out,
    output [15:0]       udp_length_out,
    input               udp_axis_tready_in
);

wire [9:0]      fifo_din, fifo_dout;
wire            fifo_wr_ena, fifo_rd_ena;
wire            fifo_empty, fifo_full;

reg             fifo_dout_valid;

reg [13:0]      byte_cnt;
reg [7:0]       data_buf[0:3];
reg [13:0]      udp_length;
wire [31:0]     data_4bytes;
wire [15:0]     data_2bytes;
integer         k;

always @(posedge clk) begin
    if (reset) begin
        byte_cnt <= 'h0;
    end
    else if (udp_axis_tlast_in) begin
        byte_cnt <= 'h0;
    end
    else if (udp_axis_tvalid_in) begin
        byte_cnt <= byte_cnt + 1'h1;
    end
    else begin
        byte_cnt <= byte_cnt;
    end
end

always @(posedge clk) begin
    if (reset) begin
        udp_length <= 'h0;
        for (k = 0; k < 4; k = k + 1) begin
            data_buf[k] <= 'h0;
        end
    end
    else begin
        if (udp_axis_tvalid_in) begin
            data_buf[3] <= data_buf[2];
            data_buf[2] <= data_buf[1];
            data_buf[1] <= data_buf[0];
            data_buf[0] <= udp_axis_tdata_in;
        end

        if (byte_cnt == 'd3 && udp_axis_tvalid_in) begin
            udp_length <= {1'b0, data_2bytes[13:0]};
        end
        else if (udp_axis_tlast_in) begin
            udp_length <= 'h0;
        end
        else begin
            udp_length <= udp_length;
        end

    end
end
assign data_4bytes = {data_buf[2], data_buf[1], data_buf[0], udp_axis_tdata_in};
assign data_2bytes = {data_buf[0], udp_axis_tdata_in};
assign udp_length_out = udp_length;

axis_8to32 axis8to32_i (
    .clk_8(clk),
    .reset_8(reset),
    .axis_tdata_in(udp_axis_tdata_in),
    .axis_tvalid_in(udp_axis_tvalid_in),
    .axis_tlast_in(udp_axis_tlast_in),
    .axis_tready_out(udp_axis_tready_out),

    .clk_32(clk_32),
    .reset_32(reset_32),
    .axis_tready_in(udp_axis_tready_in),
    .axis_tdata_out(udp_axis_tdata_out),
    .axis_tfirst_out(udp_axis_tfirst_out),
    .axis_tvalid_out(udp_axis_tvalid_out),
    .axis_tkeep_out (udp_axis_tkeep_out),
    .axis_tlast_out(udp_axis_tlast_out)
);

/*
// FIFO should always keep NOT full to ensure buffering the input UDP stream.
// Here suppose the FIFO is not overfull.
assign udp_axis_tready_out = ~fifo_full;
assign fifo_rd_ena = ~fifo_empty;
always @(posedge clk) begin
    if (reset) begin
        fifo_dout_valid <= 1'b0;
    end
    else begin
        fifo_dout_valid <= fifo_rd_ena;
end

assign fifo_wr_ena = udp_axis_tvalid_in;
assign fifo_din = {udp_axis_tlast_in, udp_axis_tvalid_in, udp_axis_tdata_in};
assign udp_axis_tvalid_out = fifo_dout_valid ? fifo_dout[8] : 1'b0;
assign udp_axis_tlast_out = fifo_dout_valid ? fifo_dout[9] : 1'b0;
assign udp_axis_tdata_out = fifo_dout[7:0];

// MSB pop out first
fifo_8inx2048 fifo_i (
  .rst(reset),        // input wire rst
  .wr_clk(clk_32),  // input wire wr_clk
  .rd_clk(clk_8),  // input wire rd_clk
  .din(fifo_din),        // input wire [31 : 0] din
  .wr_en(fifo_wr_ena),    // input wire wr_en
  .rd_en(fifo_rd_ena),    // input wire rd_en
  .dout(fifo_dout),      // output wire [7 : 0] dout
  .full(fifo_full),      // output wire full
  .empty(fifo_empty)    // output wire empty
);
*/
endmodule