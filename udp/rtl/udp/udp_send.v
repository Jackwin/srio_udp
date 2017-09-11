`timescale 1ns / 1ps

/********************************************************************************

udp_send.v

Takes in data from the application along with a valid bit, an IP address and destination port number, and encapsulates it with the UDP header.  Outputs the data, a valid bit, the destination IP address, and the data length.

Current implementation does not utilize checksum.

*********************************************************************************/

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
    input [31:0]        data_in,
    input               data_valid_in,
    input [3:0]         data_keep_in,
    input               data_last_in,
    output              data_ready_out,

    input [31:0]        ip_addr_in,
    input [15:0]        dest_port,
    input [15:0]        length_in,

    //udp data out
    output reg [31:0]   ip_addr_out,

    input               data_ready_in,
    output reg [31:0]   data_out,
    output reg          data_valid_out,
    output reg [3:0]    data_keep_out,
    output reg          data_last_out,
    output reg [15:0]   length_out

);

reg [2:0]               cnt, bufcnt;
reg [31:0]              data_buffer1, data_buffer2;
reg [3:0]               keep_buf1, keep_buf2;
reg                     last_buf1, last_buf2;
reg                     valid_buf1, valid_buf2;

assign data_ready_out = data_ready_in;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt <= 2'h0;
        bufcnt <= 2'h0;
        ip_addr_out <= 32'b0;
        data_valid_out <= 1'b0;
        data_out <= 32'b0;
        data_keep_out <= 'h0;
        data_last_out <= 1'b0;
        length_out <= 16'b0;
        data_buffer1 <= 32'b0;
        data_buffer2 <= 32'b0;
        {keep_buf2, keep_buf1} <= 'h0;
        {last_buf2, last_buf1} <= 'h0;
        {valid_buf2, valid_buf1} <= 'h0;
      end
    else if (data_valid_in && data_ready_in) begin
         case (cnt)
           0: begin
              data_out <= {`SOURCE_PORT, dest_port};
              data_valid_out <= 1'b1;
              data_keep_out <= 4'b1111;
              data_last_out <= 1'b0;
              ip_addr_out <= ip_addr_in;
              length_out <= length_in + 16'h8;
              data_buffer1 <= data_in;
              valid_buf1 <= data_valid_in;
              keep_buf1 <= data_keep_in;
              last_buf1 <= data_last_in;
              cnt <= cnt + 2'b1;
              bufcnt <= bufcnt + 2'h1;
           end
           1: begin
              data_out <= {length_out, `CHECKSUM};
              data_valid_out <= 1'b1;
              data_keep_out <= 4'b1111;
              data_last_out <= 1'b0;

              data_buffer2 <= data_buffer1;
              data_buffer1 <= data_in;
              valid_buf2 <= valid_buf1;
              valid_buf1 <= data_valid_in;
              keep_buf2 <= keep_buf1;
              keep_buf1 <= data_keep_in;
              last_buf2 <= last_buf1;
              last_buf1 <= data_last_in;

              cnt <= cnt + 2'b1;
              bufcnt <= bufcnt + 2'h1;
           end
           2: begin
              data_valid_out <= valid_buf2;
              data_out <= data_buffer2;
              data_keep_out <= keep_buf2;
              data_last_out <= last_buf2;
              data_buffer2 <= data_buffer1;
              data_buffer1 <= data_in;
              valid_buf2 <= valid_buf1;
              valid_buf1 <= data_valid_in;
              keep_buf2 <= keep_buf1;
              keep_buf1 <= data_keep_in;
              last_buf2 <= last_buf1;
              last_buf1 <= data_last_in;

           end
           default: cnt <= 2'h0;
         endcase
    end
    else if (~data_valid_in && data_ready_in) begin
         if (bufcnt != 2'h0) begin
            data_valid_out <= valid_buf2;
            data_out <= data_buffer2;
            data_keep_out <= keep_buf2;
            data_last_out <= last_buf2;

            data_buffer2 <= data_buffer1;
            valid_buf2 <= valid_buf1;
            keep_buf2 <= keep_buf1;
            last_buf2 <= last_buf1;
            //data_buffer1 <= data_in;

            bufcnt <= bufcnt - 2'h1;
            cnt <= 2'h0;
         end
        else begin
            data_valid_out <= 1'b0;
            data_keep_out <= 'h0;
            data_last_out <= 1'b0;
            cnt <= 2'h0;
        end
    end
end
endmodule
