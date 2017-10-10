`timescale 1ns/1ps
module udp2srio_interface #
    (
    parameter DATA_WIDTH = 64,
    parameter DATA_LEN_WIDTH = 20,
    parameter RAM_ADDR_WIDTH = 10,
    parameter DEBUG  = 0
    )
    (
    input                   clk_udp,    // Clock
    input                   reset_udp,

    input [31:0]            udp_data_in,
    input                   udp_valid_in,
    input                   udp_first_in,
    input [3:0]             udp_keep_in,
    input                   udp_last_in,
    input [15:0]            udp_length_in,
    output                  udp_ready_out,

    input                   clk_srio,
    input                   reset_srio,

    input                   srio_ready_in,
    output                  nwr_req_out,
    output  [15:0]          srio_length_out,
    output [DATA_WIDTH-1:0] srio_data_out,
    output                  srio_valid_out,
    output                  srio_first_out,
    output [DATA_WIDTH/8-1:0] srio_keep_out,
    output                  srio_last_out

);

wire                    fifo_wr_clk = clk_udp;
wire                    fifo_rd_clk = clk_srio;
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

(* ASYNC_REG = "TRUE" *) reg [15:0]       length_buf2, length_buf1, length_buf0;

assign data_2words = {data_buf, udp_data_in};
assign keep_2words = {keep_buf, udp_keep_in};
assign fifo_din = {data_2words, data_keep, data_last, data_valid, first_buf};
assign udp_ready_out = ~fifo_full;

assign fifo_wr_ena = data_valid;
assign fifo_rd_ena = (srio_ready_in && ~fifo_empty);
assign srio_data_out = fifo_dout[74:11];
assign srio_valid_out = fifo_dout_valid;
assign {srio_keep_out, srio_last_out} = fifo_dout_valid ? fifo_dout[10:2] : 'h0;
//assign {srio_keep_out, srio_last_out, srio_valid_out, srio_first_out} = fifo_dout_valid ? fifo_dout[10:0]
//                                        : {srio_keep_out, srio_last_out, srio_valid_out,srio_first_out};
assign srio_first_out = fifo_dout[0];
assign nwr_req_out = srio_first_out;
always @(posedge clk_srio) begin
    if (reset_srio) begin
        {length_buf2, length_buf1, length_buf0} <= 'h0;
        fifo_dout_valid <= 1'b0;
    end
    else begin
        fifo_dout_valid <= fifo_rd_ena;
        length_buf0 <= udp_length_in;
        length_buf1 <= length_buf0;
        length_buf2 <= length_buf1;
    end
end
assign srio_length_out = length_buf2;

always @(posedge clk_udp) begin
    if (reset_udp) begin
        data_buf <= 'h0;
        keep_buf <= 'h0;
        first_buf <= 1'b0;
    end
    else begin
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

fifo_75x256 fifo_75x256_i (
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

generate
    if (DEBUG == 1) begin

        wire [0:0] nwr_req_ila;
        wire [0:0] srio_ready_ila;
        wire [0:0] srio_valid_ila;
        wire [0:0] srio_first_ila;
        wire [0:0] srio_last_ila;
        assign srio_ready_ila[0] = srio_ready_in;
        assign srio_valid_ila[0] = srio_valid_out;
        assign nwr_req_ila[0] = nwr_req_out;
        assign srio_first_ila[0] = srio_first_out;
        assign srio_last_ila[0] = srio_last_out;
        ila_udp2srio ila_udp2srio_i
         (
            .clk(clk_srio), // input wire clk
            .probe0(srio_ready_ila), // input wire [0:0]  probe0
            .probe1(srio_valid_ila), // input wire [0:0]  probe1
            .probe2(nwr_req_ila), // input wire [0:0]  probe2
            .probe3(srio_first_ila), // input wire [0:0]  probe3
            .probe4(srio_last_ila), // input wire [0:0]  probe4
            .probe5(srio_keep_out), // input wire [7:0]  probe5
            .probe6(srio_length_out), // input wire [15:0]  probe6
            .probe7(srio_data_out) // input wire [63:0]  probe7
        );
        end

endgenerate


endmodule