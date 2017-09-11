`timescale 1ns/1ps

`define IP_PRTC 16'h0800
`define DATA_HEADER_LENGTH 8'd2
`define CMD_FLAG 2'b10
`define DATA_FLAG 2'b01
/*****
0          7            15            23                31
|-------------------------------------------------------|
|     32-bit Ehernet Des MAC address                    |
|-------------------------------------------------------|
|      16-bit recv_mac   |   16-bit  Source MAC address |
|-------------------------------------------------------|
|              32-bit Source MAC address                |
|-------------------------------------------------------|
|           IP_PTR       |     16-bit Data Header       |
|-------------------------------------------------------|
|        Data Length     |           User Data          |
|-------------------------------------------------------|


Data Header[15:0]
[15:14]: flag of COMMAND or DATA, 2'b01 command, 2'b10 data

COMMAND:
        [13:12]: 2'b00
        [11:8]:
                1) 4'd1 self_check
                2) 4'd5 DSP_ready
                3) 4'da DSP_not_ready
DATA: [13；12]: 2'b00
      [11:8]: 4'd1
[7:0]； Reserved

Data length [15:0]
*/

module recv_mac (
    input           clk,    // Clock
    input           reset,
    input [47:0]    mac_addr,

    //input port
    input [7:0]     axis_tdata_in,
    input           axis_tvalid_in,
    input           axis_tlast_in,
    output          axis_tready_o,

    //command output
    output reg [7:0]    cmd_tdata_out,
    output reg          cmd_tvalid_out,
    output reg          cmd_tlast_out,
    input               cmd_tready_in,

    output reg [7:0]    axis_tdata_out,
    output reg          axis_tvalid_out,
    output              axis_tfirst_out,
    output reg          axis_tlast_out,

    output reg [15:0]   data_len_out

);
localparam           IDLE_s = 3'h0;
localparam           MAC_s = 3'd1;
localparam           HEADER_RECV_s = 3'd2;
localparam           DATA_LENGTH_s = 3'd3
localparam           DATA_RECV_s = 3'd4;
localparam           END_s = 3'd5;
localparam           BUF_DEPTH = 6;

reg [2:0]            state;
reg [1:0]            recv_state;

reg [7:0]            data_buf[0:BUF_DEPTH-1];
wire [8*6-1:0]       data_6bytes;
wire [8*2-1:0]       data_2bytes;

reg [15:0]           byte_cnt;

// Timer signals
wire                timer_ena;
wire                timer_out;

reg                 axis_tfirst_r;
// Input signals
integer              k;

assign axis_tready_o = 1'b1;

always @(posedge clk) begin
    if (reset) begin
        for (k = 0; k < BUF_DEPTH; k = k + 1) begin
            data_buf[k] <= 'h0;
        end
    end
    else begin
        if (axis_tvalid_in) begin
            for (k = 0; k < (BUF_DEPTH - 1); k = k + 1) begin
                data_buf[k + 1] <= data_buf[k];
            end
            data_buf[0] <= axis_tdata_in;
        end
        else begin
            for (k = 0; k < BUF_DEPTH; k = k + 1) begin
                data_buf[k] <= data_buf[k];
            end
        end
    end
end
assign data_6bytes = {data_buf[4], data_buf[3], data_buf[2],
                     data_buf[1], data_buf[0], axis_tdata_in};
assign data_2bytes = {data_buf[0], axis_tdata_in};

always @(posedge clk) begin
    if (reset) begin
        axis_tdata_out <= 32'h0;
        axis_tvalid_out <= 1'b0;
        axis_tlast_out <= 1'b0;
        axis_tfirst_out <= 1'b0;
        data_len_out <= 'h0;
        timer_ena <= 1'b0;

        cmd_tdata_out <= 'h0;
        cmd_tvalid_out <= 1'b0;
        cmd_tlast_out <= 1'b0;

        state <= IDLE_s;
        byte_cnt <= 'h0;
      end
    else begin
         case(state)
            IDLE_s: begin
                data_len_out <= 'h0;
                axis_tlast_out <= 1'b0;
                if (data_6bytes == mac_addr) begin
                    state <= MAC_s;
                end
                else begin
                    state <= IDLE_s;
                end
            end
            // TODO: Set up timer
            MAC_s: begin
                if (data_2bytes == `IP_PRTC && axis_tvalid_in) begin
                    $display("Ethernet package found.\n");
                    next_state_IP <= 1'b1;
                    state <= DATA_RECV_HEADER_s;
                    byte_cnt <= 'h0;
                end
                else if (timer_out)begin
                    state <= IDLE_s;
                    timer_ena <= 1'b0;
                end
                else begin
                    timer_ena <= 1'b1;
                    state <= MAC_s;
                end
            end

            HEADER_RECV_s: begin
                if (axis_tvalid_in && data_2bytes[15:14] == `CMD_FLAG) begin
                    cmd_tdata_out <= data_2bytes[15:8];
                    cmd_tvalid_out <= 1'b1;
                    cmd_tlast_out <= axis_tlast_in;
                    state <= IDLE_s;
                    $display("Command Found.\n");
                end
                else if (axis_tvalid_in && data_2bytes[15:14] == `DATA_FLAG) begin
                    cmd_tdata_out <= data_2bytes[15:8];
                    cmd_tvalid_out <= 1'b1;
                    cmd_tlast_out <= axis_tlast_in;
                    state <= DATA_RECV_s;
                    $display("Data Found.\n");
                else begin
                    cmd_tdata_out <= 'h0;
                    cmd_tvalid_out <= 1'b0;
                    cmd_tlast_out <= 1'b0;
                    state <= DATA_LENGTH_s;
                end
            end

            DATA_LENGTH_s: begin
                if (byte_cnt == 'd1) begin
                    state <= DATA_RECV_s;
                    data_len_out <= data_2bytes;
                    byte_cnt <= 'd0;
                end
                else if (axis_tvalid_in) begin
                    byte_cnt <= byte_cnt + 'd1;
                end
            end

            DATA_RECV_s: begin
                axis_tdata_out <= axis_tdata_in;
                axis_tvalid_out <= axis_tvalid_in;
                axis_tlast_out <= axis_tlast_in;
                if (axis_tlast_in) begin
                    state <=END_s;
                end
                else begin
                    state <= DATA_RECV_s;
                end
            end
            END_s: begin
                axis_tlast_out <= 1'b0;
                state <= IDLE_s;
            end
            default: begin
                state <= IDLE_s;
            end
        endcase // state
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        axis_tfirst_r <= 1'b1;
    end
    else begin
        if (axis_tvalid_out) begin
            axis_tfirst_r <= 1'b0;
        end
        else if (axis_tlast_out) begin
            axis_tlast_r <= 1'b1;
        end
    end
end
assign axis_tfirst_out = (axis_tlast_r & axis_tvalid_out);

timer #
(   .TIMER_WIDTH(10))
timer_self_check
(
    .clk      (clk),
    .reset    (reset),
    .enable   (timer_ena),
    .timer_out(timer_out)
);

endmodule