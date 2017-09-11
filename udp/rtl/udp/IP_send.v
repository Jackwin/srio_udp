
/**************************************************************
 * Module: IP_send
 * Porject: Packet filter in 10Gb/s network
 * Description:
 * 1) Send the IP data
 **************************************************************/
//0           7        15                             31
//-------------------------------------------------------------
// ver | IHL | TOS         |     16-bit destination port  |
//------------------------------------------------------------
//    ID base              | Flah | 13-bit offset         |
//-------------------------------------------------------------
//      TTL  | Protocal    |           Check-sum          |
//-------------------------------------------------------------
//                      Source IP                         |
//-------------------------------------------------------------
//                       Destination IP
//-------------------------------------------------------------
`timescale 1ps / 1ps

`define VERSION 4'h4
`define IHL 4'h5
`define TOS 8'h0
`define SRC_ADDR 32'hc0a80102
`define ID_BASE 16'h0
`define FLAG 3'b010
`define FRAGMENT_OFFSET 13'h0
`define TTL 8'h40
`define UDP_PROTOCOL 8'h11
`define UDP_CHKSUM_BASE 16'h86bc

`define TCP_PROTOCOL 8'h06
`define TCP_CHKSUM_BASE 16'h86b1

module ip_send
(
    input               clk,
    input               reset,
    input [31:0]        ip_addr,
    // from UDP send
    input [31:0]        udp_data_in,
    input               udp_valid_in,
    input [3:0]         udp_keep_in,
    input               udp_last_in,
    output              udp_ready_out,
    input [15:0]        udp_data_length_in,
    // from TCP send
    input [31:0]        tcp_data_in,
    input               tcp_valid_in,
    input [3:0]         tcp_keep_in,
    input               tcp_last_in,
    output              tcp_ready_out,
    input [15:0]        tcp_data_length_in,
    // send buffer
    input               ready_in,
    // output ports
    output reg          conflict_flag_out,
    output reg [31:0]   oip_addr,
    output [15:0]       data_length_out,
    output reg          length_valid_out,

    output reg [31:0]   axis_tdata_out,
    output reg          axis_tvalid_out,
    output reg [3:0]    axis_tkeep_out,
    output reg          axis_tlast_out

);
   // registers
reg [31:0]           data_buffer1, data_buffer2, data_buffer3, data_buffer4, data_buffer5, data_buffer6;

reg [31:0]           data_buffer7, data_buffer8, data_buffer9;
reg [3:0]            keep_buffer[0:8];
reg [8:0]            last_buffer;
reg [8:0]            valid_buffer;
reg [31:0]           ip_addr_reg;
reg [15:0]           total_length, datagram_cnt, accum1, accum2, chksum;
reg [15:0]           cnt;
reg [16:0]           tmp_accum1, tmp_accum2;
reg                  isvalid;
reg [3:0]            bufcnt;

reg                  valid_r;
reg [31:0]           tcp_udp_data_buf;
reg [3:0]            tcp_udp_keep_buf;
reg                  tcp_udp_last_buf;
reg                  tcp_udp_valid_buf;

integer              k;

assign udp_ready_out = ready_in;
assign tcp_ready_out = ready_in;
assign data_length_out = total_length;

// Choose the data source
always @(posedge clk or posedge reset) begin
    if (reset) begin
        valid_r <= 1'b0;
        tcp_udp_data_buf <= 'h0;
        tcp_udp_keep_buf <= 'h0;
        tcp_udp_valid_buf <= 1'b0;
        tcp_udp_last_buf <= 1'b0;
        conflict_flag_out <= 1'b0;
    end
    else begin
        case({udp_valid_in, tcp_valid_in})
            2'b00: begin
                valid_r <= 1'b0;
                tcp_udp_data_buf <= 'h0;
                tcp_udp_keep_buf <= 'h0;
                tcp_udp_valid_buf <= 1'b0;
                tcp_udp_last_buf <= 1'b0;
                conflict_flag_out <= 1'b0;
            end
            2'b01: begin
                valid_r <= 1'b1;
                tcp_udp_data_buf <= tcp_data_in;
                tcp_udp_keep_buf <= tcp_keep_in;
                tcp_udp_valid_buf <= tcp_valid_in;
                tcp_udp_last_buf <=  tcp_last_in;
                conflict_flag_out <= 1'b0;
            end
            2'b10: begin
                valid_r <= 1'b1;
                tcp_udp_data_buf <= udp_data_in;
                tcp_udp_keep_buf <= udp_keep_in;
                tcp_udp_valid_buf <= udp_valid_in;
                tcp_udp_last_buf <=  udp_last_in;
                conflict_flag_out <= 1'b0;
            end
            2'b11: begin
                valid_r <= 1'b0;
                tcp_udp_data_buf <= 'h0;
                tcp_udp_keep_buf <= 'h0;
                tcp_udp_valid_buf <= 1'b0;
                tcp_udp_last_buf <= 1'b0;
                conflict_flag_out <= 1'b1;
            end
        endcase // case ({udp_valid_in, tcp_valid_in})
    end // else: !if(reset)
end // always @ (posedge clk)


always @(posedge clk or posedge reset) begin
  isvalid <= valid_r;

    if (reset) begin
        cnt <= 16'h0;
        datagram_cnt <= 16'h0;
        ip_addr_reg <= 32'h0;
        data_buffer1 <= 32'h0;
        data_buffer2 <= 32'h0;
        data_buffer3 <= 32'h0;
        data_buffer4 <= 32'h0;
        data_buffer5 <= 32'h0;
        data_buffer6 <= 32'h0;
        valid_buffer <= 'h0;
        last_buffer <= 'h0;
        for (k = 0; k < 9; k = k + 1) begin
            keep_buffer[k] <= 'h0;
        end

         total_length <= 'h0;
         bufcnt <= 4'b1100;
         axis_tdata_out <= 32'h0;
         oip_addr <= 32'h0;
         axis_tvalid_out <= 1'b0;
         tmp_accum1 <= 'h0;
         accum1 <= 'h0;
         tmp_accum2 <= 'h0;
         accum2 <= 'h0;

    end
    else if (valid_r && ready_in) begin
         axis_tvalid_out <= 1'b0;
         length_valid_out <= 1'b0;
         axis_tkeep_out <= 'h0;
         axis_tlast_out <= 1'b0;
         case (cnt)
                0: begin
                  // start calculating header checksum
                    tmp_accum1 <= ip_addr[31:16] + ip_addr[15:0];
                  //accum1 <= tmp_accum1[15:0] + tmp_accum1[16];
                    bufcnt <= 4'b1001;
                    data_buffer1 <= tcp_udp_data_buf;
                    keep_buffer[0] <= tcp_udp_keep_buf;
                    valid_buffer[0] <= tcp_udp_valid_buf;
                    datagram_cnt <= datagram_cnt + 16'h1;
                    ip_addr_reg  <= ip_addr;
                    if (udp_valid_in) begin
                        total_length <= udp_data_length_in + (`IHL << 2);
                        length_valid_out <= 1'b1;
                    end
                    else if (tcp_valid_in )begin
                        total_length <= tcp_data_length_in + (`IHL << 2);
                        length_valid_out <= 1'b1;
                    end
                    else begin
                        total_length <= 'h0;
                    end

                    cnt <= cnt + 16'b1;
                end
                1: begin
                    accum1 <= tmp_accum1[15:0] + tmp_accum1[16];
                    // continue calculating header checksum
                    tmp_accum2 <= total_length + (`ID_BASE + datagram_cnt);
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    keep_buffer[1] <= keep_buffer[0];
                    keep_buffer[0] <= tcp_udp_keep_buf;

                    valid_buffer[1] <= valid_buffer[0];
                    valid_buffer[0] <= tcp_udp_valid_buf;

                    cnt <= cnt + 16'b1;
                end
                2: begin
                    accum2 <= tmp_accum2[15:0] + tmp_accum2[16];
                    if (udp_valid_in) begin
                        tmp_accum1 <= accum1 + `UDP_CHKSUM_BASE;  //pre-sum
                    end
                    else if (tcp_valid_in) begin
                        tmp_accum1 <= accum1 + `TCP_CHKSUM_BASE;  //pre-sum
                    end
                    data_buffer3 <= data_buffer2;
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    for (k = 0; k < 2; k = k + 1) begin
                         keep_buffer[k + 1] <= keep_buffer[k];
                        valid_buffer[k + 1] <= valid_buffer[k];
                    end
                    valid_buffer[0] <= tcp_udp_valid_buf;
                    keep_buffer[0] <= tcp_udp_keep_buf;
                    cnt <= cnt + 16'b1;
                end
                3: begin
                    accum1 <= tmp_accum1[15:0] + tmp_accum1[16];
                    data_buffer4 <= data_buffer3;
                    data_buffer3 <= data_buffer2;
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    for (k = 0; k < 3; k = k + 1) begin
                        keep_buffer[k + 1] <= keep_buffer[k];
                        valid_buffer[k + 1] <= valid_buffer[k];
                    end
                    valid_buffer[0] <= tcp_udp_valid_buf;
                    keep_buffer[0] <= tcp_udp_keep_buf;
                    cnt <= cnt + 16'b1;
               end
                4: begin
                    // final calculation of head checksum
                    tmp_accum1 <= accum1 + accum2;

                    // send first word of header
                    axis_tdata_out <= {`VERSION,`IHL,`TOS,total_length};
                    oip_addr <= ip_addr_reg;
                    // set valid high for output
                    axis_tvalid_out <= 1'b1;
                    axis_tkeep_out <= 4'hf;
                    data_buffer5 <= data_buffer4;
                    data_buffer4 <= data_buffer3;
                    data_buffer3 <= data_buffer2;
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    for (k = 0; k < 4; k = k + 1) begin
                        keep_buffer[k + 1] <= keep_buffer[k];
                        valid_buffer[k + 1] <= valid_buffer[k];
                    end
                    valid_buffer[0] <= tcp_udp_valid_buf;
                    keep_buffer[0] <= tcp_udp_keep_buf;
                    cnt <= cnt + 16'b1;
                end
                5: begin
                    // final calculation of head checksum
                    chksum <= ~(tmp_accum1[15:0] + tmp_accum1[16]);
                    // send second word of header
                    axis_tdata_out <= {`ID_BASE + datagram_cnt,`FLAG,`FRAGMENT_OFFSET};
                    axis_tvalid_out <= 1'b1;
                    axis_tkeep_out <= 4'hf;
                    // propagate data down buffer chain
                    data_buffer6 <= data_buffer5;
                    data_buffer5 <= data_buffer4;
                    data_buffer4 <= data_buffer3;
                    data_buffer3 <= data_buffer2;
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    for (k = 0; k < 5; k = k + 1) begin
                        keep_buffer[k + 1] <= keep_buffer[k];
                        valid_buffer[k + 1] <= valid_buffer[k];
                    end
                     keep_buffer[0] <= tcp_udp_keep_buf;
                    valid_buffer[0] <= tcp_udp_valid_buf;
                    cnt <= cnt + 16'b1;
               end
                6: begin
                  // send third word of header
                    if (udp_valid_in) begin
                        axis_tdata_out <= {`TTL,`UDP_PROTOCOL,chksum};
                    end
                    else if (tcp_valid_in) begin
                        axis_tdata_out <= {`TTL,`TCP_PROTOCOL,chksum};
                    end
                    axis_tvalid_out <= 1'b1;
                    axis_tkeep_out <= 4'hf;
                    // propagate data down buffer chain
                    data_buffer7 <= data_buffer6;
                    data_buffer6 <= data_buffer5;
                    data_buffer5 <= data_buffer4;
                    data_buffer4 <= data_buffer3;
                    data_buffer3 <= data_buffer2;
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    for (k = 0; k < 6; k = k + 1) begin
                        keep_buffer[k + 1] <= keep_buffer[k];
                        valid_buffer[k + 1] <= valid_buffer[k];
                    end
                    keep_buffer[0] <= tcp_udp_keep_buf;
                    valid_buffer[0] <= tcp_udp_valid_buf;
                    cnt <= cnt + 16'b1;

                end
                7: begin
                    // send fourth word of header
                    axis_tdata_out <= `SRC_ADDR;
                    axis_tvalid_out <= 1'b1;
                    axis_tkeep_out <= 4'hf;
                  // propagate data down buffer chain
                    data_buffer8 <= data_buffer7;
                    data_buffer7 <= data_buffer6;
                    data_buffer6 <= data_buffer5;
                    data_buffer5 <= data_buffer4;
                    data_buffer4 <= data_buffer3;
                    data_buffer3 <= data_buffer2;
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    for (k = 0; k < 7; k = k + 1) begin
                        keep_buffer[k + 1] <= keep_buffer[k];
                        valid_buffer[k + 1] <= valid_buffer[k];

                    end
                    keep_buffer[0] <= tcp_udp_keep_buf;
                    valid_buffer[0] <= tcp_udp_valid_buf;
                    cnt <= cnt + 16'b1;
                end
                8: begin
                    // send fifth word of header
                    axis_tdata_out <= ip_addr_reg;
                    axis_tvalid_out <= 1'b1;
                    axis_tkeep_out <= 4'hf;
                    // propagate data down buffer chain
                    data_buffer9 <= data_buffer8;
                    data_buffer8 <= data_buffer7;
                    data_buffer7 <= data_buffer6;
                    data_buffer6 <= data_buffer5;
                    data_buffer5 <= data_buffer4;
                    data_buffer4 <= data_buffer3;
                    data_buffer3 <= data_buffer2;
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    for (k = 0; k < 8; k = k + 1) begin
                        keep_buffer[k + 1] <= keep_buffer[k];
                        valid_buffer[k + 1] <= valid_buffer[k];
                    end
                    keep_buffer[0] <= tcp_udp_keep_buf;
                    valid_buffer[0] <= tcp_udp_valid_buf;

                    cnt <= cnt + 16'b1;
               end
               9: begin
                    // begin sending buffered data
                    axis_tdata_out <= data_buffer9;
                    axis_tvalid_out <= valid_buffer[8];
                    axis_tkeep_out <= keep_buffer[8];
                    data_buffer9 <= data_buffer8;
                    data_buffer8 <= data_buffer7;
                    data_buffer7 <= data_buffer6;
                    data_buffer6 <= data_buffer5;
                    data_buffer5 <= data_buffer4;
                    data_buffer4 <= data_buffer3;
                    data_buffer3 <= data_buffer2;
                    data_buffer2 <= data_buffer1;
                    data_buffer1 <= tcp_udp_data_buf;

                    for (k = 0; k < 8; k = k + 1) begin
                        keep_buffer[k + 1] <= keep_buffer[k];
                        valid_buffer[k + 1] <= valid_buffer[k];
                    end
                    keep_buffer[0] <= tcp_udp_keep_buf;
                    valid_buffer[0] <= tcp_udp_valid_buf;
                    //cnt <= cnt + 16'b1;
               end
        endcase
    end
    else if (~valid_r && ready_in && |cnt != 1'b0) begin
        if (bufcnt != 4'b0000) begin
            if (bufcnt == 4'b0001) begin
                axis_tlast_out <= 1'b1;
            end
            else begin
                axis_tlast_out <= 1'b0;
            end
            axis_tdata_out <= data_buffer9;
            axis_tkeep_out <= keep_buffer[8];
            axis_tvalid_out <= valid_buffer[8];
            data_buffer9 <= data_buffer8;
            data_buffer8 <= data_buffer7;
            data_buffer7 <= data_buffer6;
            data_buffer6 <= data_buffer5;
            data_buffer5 <= data_buffer4;
            data_buffer4 <= data_buffer3;
            data_buffer3 <= data_buffer2;
            data_buffer2 <= data_buffer1;
            data_buffer1 <= tcp_udp_data_buf;

            for (k = 0; k < 8; k = k + 1) begin
                keep_buffer[k + 1] <= keep_buffer[k];
                valid_buffer[k + 1] <= valid_buffer[k];
            end
            keep_buffer[0] <= tcp_udp_keep_buf;
            valid_buffer[0] <= tcp_udp_valid_buf;
            bufcnt <= bufcnt - 4'b0001;
        end
        else if (bufcnt == 4'b000) begin
            axis_tvalid_out <= 1'b0;
            axis_tkeep_out <= 4'h0;
            cnt <= 16'h0;
            axis_tlast_out <= 1'b0;
        end
    end
end
endmodule
