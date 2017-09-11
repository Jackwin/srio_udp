`timescale 1ps / 1ps

//UDP package
//0                       15                             31
//-------------------------------------------------------------
// 16-bit source port          |     16-bit destination port  |
//------------------------------------------------------------
// 16-bit UDP length            |      16-bit checksum          |
//-------------------------------------------------------------
//                        Data
//-------------------------------------------------------------

`define SOURCE_PORT 16'h0400
`define CHECKSUM 16'h0      // no checksum in udp
module udp_send(
    input           clk,
    input           reset,

    //udp data in
    input               app_axis_tvalid_in,
    input [7:0]         app_axis_tdata_in,
    input               app_axis_tlast_in,
    input [1:0]         op,
    input [31:0]        ip_addr_in,
    input [15:0]        dest_port,
    // length_in should be longer than 8 bytes
    input [15:0]        length_in,

    //udp data out
    output reg [31:0]   ip_addr_out,

    output reg          udp_axis_tvalid_out,
    output reg [7:0]    udp_axis_tdata_out,
    output reg          udp_axis_tlast_out,
    output reg [15:0]   length_out

);
localparam              BUF_DEPTH = 8;
reg [4:0]               cnt;
reg [3:0]               bufcnt;
reg [15:0]              dest_port_reg;

reg [7:0]               data_buf[0:BUF_DEPTH-1];
reg [7:0]               last_buf;


always @(posedge clk) begin
    if (reset) begin
        last_buf <= 'h0;
    end
    else begin
        last_buf[7:0] <= {last_buf[6:0], app_axis_tlast_in};
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt <= 4'h0;
        bufcnt <= 3'h0;
        ip_addr_out <= 32'b0;
        length_out <= 16'b0;
        udp_axis_tvalid_out <= 1'b0;
        udp_axis_tdata_out <= 'h0;
        udp_axis_tlast_out <= 1'b0;
        dest_port_reg <= 'h0;
    end
    else if (app_axis_tvalid_in && op == 'h1) begin
        udp_axis_tlast_out <= 1'b0;
        case (cnt)
            0: begin
                udp_axis_tdata_out <= `SOURCE_PORT[15:8];
                udp_axis_tvalid_out <= 1'b1;

                ip_addr_out <= ip_addr_in;
                length_out <= length_in + 16'h8;
                dest_port_reg <= dest_port;
                cnt <= cnt + 4'd1;
                bufcnt <= bufcnt + 3'h1;
                data_buf[0] <= udp_axis_tdata_in;
                $display("Start sending UDP packet.");
            end
            1: begin
                udp_axis_tdata_out <= `SOURCE_PORT[7:0];
                udp_axis_tvalid_out <= 1'b1;
                cnt <= cnt + 4'd1;
                bufcnt <= bufcnt + 3'd1;
                data_buf[1] <= data_buf[0];
                data_buf[0] <= udp_axis_tdata_in;
            end
            2: begin
                udp_axis_tdata_out <= dest_port_reg[15:8];
                udp_axis_tvalid_out <= 1'b1;
                cnt <= cnt + 4'd1;
                bufcnt <= bufcnt + 3'd1;
                data_buf[2] <= data_buf[1];
                data_buf[1] <= data_buf[0];
                data_buf[0] <= udp_axis_tdata_in;
            end
            3: begin
                udp_axis_tdata_out <= dest_port_reg[7:0];
                udp_axis_tvalid_out <= 1'b1;
                cnt <= cnt + 4'd1;
                bufcnt <= bufcnt + 3'd1;
                data_buf[3] <= data_buf[2];
                data_buf[2] <= data_buf[1];
                data_buf[1] <= data_buf[0];
                data_buf[0] <= udp_axis_tdata_in;
            end
            4: begin
                udp_axis_tdata_out <= length_out[15:8];
                udp_axis_tvalid_out <= 1'b1;
                cnt <= cnt + 4'd1;
                bufcnt <= bufcnt + 3'd1;
                data_buf[4] <= data_buf[3];
                data_buf[3] <= data_buf[2];
                data_buf[2] <= data_buf[1];
                data_buf[1] <= data_buf[0];
                data_buf[0] <= udp_axis_tdata_in;
            end
            5: begin
                udp_axis_tdata_out <= length_out[7:0];
                udp_axis_tvalid_out <= 1'b1;
                cnt <= cnt + 4'd1;
                bufcnt <= bufcnt + 3'd1;
                data_buf[5] <= data_buf[4];
                data_buf[4] <= data_buf[3];
                data_buf[3] <= data_buf[2];
                data_buf[2] <= data_buf[1];
                data_buf[1] <= data_buf[0];
                data_buf[0] <= udp_axis_tdata_in;
            end
            6: begin
                udp_axis_tdata_out <= `CHECKSUM[15:8];
                udp_axis_tvalid_out <= 1'b1;
                cnt <= cnt + 4'd1;
                bufcnt <= bufcnt + 3'd1;
                data_buf[6] <= data_buf[5];
                data_buf[5] <= data_buf[4];
                data_buf[4] <= data_buf[3];
                data_buf[3] <= data_buf[2];
                data_buf[2] <= data_buf[1];
                data_buf[1] <= data_buf[0];
                data_buf[0] <= udp_axis_tdata_in;
            end
            7: begin
                udp_axis_tdata_out <= `CHECKSUM[7:0];
                udp_axis_tvalid_out <= 1'b1;
                cnt <= cnt + 4'd1;
                bufcnt <= bufcnt + 3'd1;
                data_buf[7] <= data_buf[6];
                data_buf[6] <= data_buf[5];
                data_buf[5] <= data_buf[4];
                data_buf[4] <= data_buf[3];
                data_buf[3] <= data_buf[2];
                data_buf[2] <= data_buf[1];
                data_buf[1] <= data_buf[0];
                data_buf[0] <= udp_axis_tdata_in;
            end
            8: begin
                udp_axis_tdata_out <= data_buf[7];
                udp_axis_tvalid_out <= 1'b1;
                data_buf[7] <= data_buf[6];
                data_buf[6] <= data_buf[5];
                data_buf[5] <= data_buf[4];
                data_buf[4] <= data_buf[3];
                data_buf[3] <= data_buf[2];
                data_buf[2] <= data_buf[1];
                data_buf[1] <= data_buf[0];
                data_buf[0] <= udp_axis_tdata_in;
            end
            default: begin
                udp_axis_tdata_out <= 'h0;
                udp_axis_tvalid_out <= 1'b0;
                udp_axis_tlast_out <= 1'b0;
                cnt <= 'h0;
                bufcnt <= 'h0;
            end
        endcase
    end
    else if (~udp_axis_tdata_in && op == 1'h1) begin
        if (bufcnt != 3'h0) begin
            udp_axis_tdata_out <= data_buf[7];
            data_buf[7] <= data_buf[6];
            data_buf[6] <= data_buf[5];
            data_buf[5] <= data_buf[4];
            data_buf[4] <= data_buf[3];
            data_buf[3] <= data_buf[2];
            data_buf[2] <= data_buf[1];
            data_buf[1] <= data_buf[0];
            data_buf[0] <= udp_axis_tdata_in;
            udp_axis_tvalid_out <= 1'b1;
            udp_axis_tlast_out <= last_buf[7];
            bufcnt <= bufcnt - 3'd1;
            cnt <= 'h0;
        end
        else begin
            udp_axis_tvalid_out <= 1'b0;
            udp_axis_tlast_out <= 1'b0;
            cnt <= 'h0;
        end
    end
end
endmodule

