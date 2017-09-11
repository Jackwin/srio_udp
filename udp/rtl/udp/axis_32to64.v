`timescale 1ns/1ps
module udp2rapidio_interface #
    (
    parameter DATA_WIDTH = 64,
    parameter DATA_LEN_WIDTH = 20,
    parameter RAM_ADDR_WIDTH = 10
        )
    (
    input                   clk_udp,    // Clock
    input                   reset_udp,

    input [31:0]            udp_data_in,
    input                   udp_valid_in,
    input                   udp_first_in,
    input [3:0]             udp_keep_in,
    input                   udp_last_in,
    output                  udp_ready_out,

    input                   clk_rapid,
    input                   reset_rapid,

    input                   rapid_ready_in,
    input                   rapid_ack_in,
    input  [DATA_LEN_WIDTH-1:0] rapid_length_in,
    output [DATA_WIDTH-1:0] rapid_data_out,
    output                  rapid_valid_out,
    output                  rapid_first_out,
    output [DATA_WIDTH/8-1:0] rapid_keep_out,
    output                  rapid_last_out

);

wire                    fifo_wr_clk = clk_udp;
wire                    fifo_rd_clk = clk_rapid;
wire                    fifo_reset = reset_udp;

wire [64+8+1+1+1-1:0]     fifo_din, fifo_dout;
wire                    fifo_empty, fifo_full;
wire                    fifo_wr_ena, fifo_rd_ena;
reg                     fifo_dout_valid;

reg                     word_cnt;
wire [63:0]             data_2words;
wire [7:0]              keep_2words;
reg [31:0]              data_buf;
reg [3:0]               keep_buf;
reg                     first_buf;

reg [7:0]               data_keep;
reg                     data_last;
reg                     data_valid;
reg                     data_first;

assign data_2words = {data_buf, udp_data_in};
assign keep_2words = {keep_buf, udp_keep_in};
assign fifo_din = {data_2words, data_keep, data_last, first_buf, data_valid};
assign udp_ready_out = ~fifo_full;

assign fifo_wr_ena = data_valid;
assign fifo_rd_ena = (rapid_ready_in && ~fifo_empty);
assign rapid_data_out = fifo_dout[74:11];
assign rapid_valid_out = fifo_dout_valid;
assign {rapid_keep_out, rapid_last_out, rapid_first_out} = fifo_dout_valid ? fifo_dout[10:1] : 'h0;
//assign {rapid_keep_out, rapid_last_out, rapid_valid_out, rapid_first_out} = fifo_dout_valid ? fifo_dout[10:0]
                                      // : {rapid_tkeep_out, rapid_tlast_out, rapid_tvalid_out,rapid_first_out};

always @(posedge clk_udp) begin
    if (reset_udp) begin
        data_buf <= 'h0;
        keep_buf <= 'h0;
        fifo_dout_valid <= 1'b0;
        first_buf <= 1'b0;
    end
    else begin
        fifo_dout_valid <= fifo_rd_ena;
        if (udp_valid_in) begin
            data_buf <= udp_data_in;
            keep_buf <= udp_keep_in;
            first_buf <= udp_first_in;

        end
    end
end

always @(posedge clk_udp) begin
    if (reset_udp) begin
        word_cnt <= 'h0;
    end
    else begin
        if (udp_last_in) begin
            word_cnt <= 1'b0;
        end
        else if(udp_valid_in) begin
            word_cnt <= ~word_cnt;
        end
    end
end

always @(*) begin
    case(word_cnt)
        1'b0: begin
            if (udp_valid_in && udp_last_in) begin
                data_keep = {4'b0000, udp_keep_in};
                data_last = 1'b1;
                data_valid = 1'b1;
            end
            else begin
                data_keep = 'h0;
                data_last = 1'b0;
                data_valid = 1'b0;
            end
        end
        1'b1: begin
            if (udp_valid_in && !udp_last_in) begin
                data_keep = keep_2words;
                data_last = 1'b0;
                data_valid = 1'b1;
            end
            else if (udp_valid_in && udp_last_in) begin
                data_keep = keep_2words;
                data_last = 1'b1;
                data_valid = 1'b1;
            end
            else begin
                data_keep = 'h0;
                data_last = 1'b0;
                data_valid = 1'b0;
            end
        end
    endcase // word_cnt
end

fifo_74x256 fifo_74x256_i (
    .rst(reset_udp),
    .wr_clk(fifo_wr_clk),
    .rd_clk(fifo_rd_clk),
    .din(fifo_din),
    .wr_en(fifo_wr_ena),
    .rd_en(fifo_rd_ena),
    .dout(fifo_dout),
    .full(fifo_full),
    .empty(fifo_empty)

    );


endmodule