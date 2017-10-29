/**************

udp_rcv.v

Takes in data from IP_recv.v when udp_valid is high, strips the UDP header, and serves the raw data to the application layer.
Current implementation does not utilize checksum.

**************/

module udp_rcv #
    ( parameter DEBUG = 0)
    (
    input               clk,
    input               reset,

    input [7:0]         udp_axis_tdata_in,
    input               udp_axis_tvalid_in,
    input               udp_axis_tlast_in,
    output              udp_axis_tready_out,

    input wire          udpdata_tready_in,
    output reg [7:0]    udpdata_tdata_out,
    output reg          udpdata_tvalid_out,
    output reg          udpdata_tlast_out,
    output wire [15:0]  udpdata_length_out,
    output reg [15:0]   dest_port_out,

    output [7:0]        cmd_out,
    output              cmd_valid_out
);
localparam              BUF_DEPTH = 6;
reg [4:0]               cnt;
reg [10:0]              byte_cnt;
reg [15:0]              source_port, length, checksum;
reg                     start_data;
wire [15:0]             data_length;
reg [15:0]              data_length_countdown;

reg [7:0]               data_buf[0:BUF_DEPTH-1];
wire [8*2-1:0]          data_2bytes;
integer                 k;

wire [0:0]              udp_tvalid_ila;
wire [0:0]              udp_tlast_ila;
wire [0:0]              udp_tready_ila;

//assign udp_axis_tready_out = 1'b1;
assign udp_axis_tready_out = udpdata_tready_in;

assign udpdata_length_out = (length == 16'b0) ? 16'b0 : (length - 8); //number of total bytes divided by 4 makes the number of total words, and subtract 2 words for the header

always @(posedge clk) begin
    if (reset) begin
      for (k = 0; k < BUF_DEPTH; k = k + 1) begin
        data_buf[k] <= 'h0;
      end
    end
    else begin
      if (udp_axis_tvalid_in) begin
        for (k = 0; k < (BUF_DEPTH - 1); k = k + 1) begin
          data_buf[k + 1] <= data_buf[k];
        end
        data_buf[0] <= udp_axis_tdata_in;
      end
      else begin
        for (k = 0; k < BUF_DEPTH; k = k + 1) begin
          data_buf[k] <= data_buf[k];
        end
      end
    end
end

assign data_2bytes = {data_buf[0], udp_axis_tdata_in};

always @(posedge clk) begin
    if (reset) begin
        cnt <= 'h0;
        byte_cnt <= 'h0;
        udpdata_tvalid_out <= 1'b0;
        udpdata_tdata_out <= 7'b0;
        udpdata_tlast_out <= 1'b0;
        source_port <= 16'b0;
        dest_port_out <= 16'b0;
        length <= 16'b0;
        checksum <= 16'b0;
    end
    else begin
        if (udp_axis_tvalid_in && udpdata_tready_in) begin
            byte_cnt <= byte_cnt + 'h1;
            case (cnt)
                0,2,4,6: begin
                    cnt <= cnt + 4'b1;
                end
                1: begin
                    source_port <= data_2bytes;
                    cnt <= cnt + 4'b1;
                end
                3: begin
                    dest_port_out <= data_2bytes;
                    cnt <= cnt + 4'b1;
                end
                5: begin
                    length <= data_2bytes;
                    cnt <= cnt + 4'b1;
                end
                7: begin
                    checksum <= data_2bytes;
                    cnt <= cnt + 4'b1;
                end
                8: begin
                    udpdata_tdata_out <= udp_axis_tdata_in;
                    udpdata_tvalid_out <= udp_axis_tvalid_in;
                    udpdata_tlast_out <= udp_axis_tlast_in;
                    if (udp_axis_tlast_in) begin
                        cnt <= cnt + 4'b1;
                    end
                end
                9: begin
                    cnt <= 'h0;
                    udpdata_tdata_out <= 'h0;
                    udpdata_tvalid_out <= 1'b0;
                    udpdata_tlast_out <= 1'b0;

                end
                default: begin
                    cnt <= 'h0;
                end
            endcase // cnt
        end
        else begin
            byte_cnt <= byte_cnt;
            cnt <= cnt;
            udpdata_tdata_out <= udp_axis_tdata_in;
            udpdata_tvalid_out <= 1'b0;
            //udpdata_tlast_out <= (length < 49) ? (byte_cnt == (length - 1)) : udp_axis_tlast_in;
            udpdata_tlast_out <= udp_axis_tlast_in;
            source_port <= source_port;
            dest_port_out <= dest_port_out;
        end
        //if (udp_axis_tlast_in) begin
        if (udpdata_tlast_out) begin
            cnt <= 'h0;
            byte_cnt <= 'h0;
        end
    end
end

cmd_parse cmd_parse_i (
    .clk          (clk),
    .reset        (reset),
    .data_in      (udp_axis_tdata_in),
    .valid_in     (udp_axis_tvalid_in),
    .last_in      (),

    .cmd_out      (cmd_out),
    .cmd_valid_out(cmd_valid_out)
    );
generate
    if (DEBUG == 1) begin
        assign udp_tvalid_ila[0] = udpdata_tvalid_out;
        assign udp_tlast_ila[0] = udpdata_tlast_out;
        assign udp_tready_ila[0] = udpdata_tready_in;
        ila_udp ila_udp_i (
                .clk(clk), // input wire clk
                .probe0(udpdata_tdata_out), // input wire [7:0]  probe0
                .probe1(udp_tvalid_ila), // input wire [0:0]  probe1
                .probe2(udp_tlast_ila), // input wire [0:0]  probe2
                .probe3(udp_tready_ila) // input wire [0:0]  probe3
            );
    end
endgenerate

endmodule


module cmd_parse (
    input           clk,
    input           reset,

    input [7:0]     data_in,
    input           valid_in,
    input           last_in,
    //FPGA command
    output          fpga_self_check_out,
    output          srio_self_check_out,
    output          loopback422_self_check_out,
    output          lvds_ctrl_out,
    output          image_lvds_out,
    output          ctrl_lvds_config_out,
    output          image_lvds_config_out,
    output          com_422_test_out,
    output          srio_file_load_out,
    output          ctrl_lvds_file_out,
    output          srio_test_out,
    output          ctrl_lvds_test_out,

    output reg [7:0]    cmd_out,
    output reg          cmd_valid_out,
    output reg          checkgood_out,
    output reg          checkbad_out,

    input               axis_tready_in,
    output reg [7:0]    axis_tdata_out,
    output reg          axis_tvalid_out,
    output reg          axis_tlast_out

);
localparam IDLE_s = 3'b000;
localparam CMD_s = 3'b001;
localparam DATA_s = 3'b010;
localparam DATA_FILE_s = 3'b011;
localparam CHECK_s = 3'b100;
localparam TAIL_s = 3'b101;
localparam FPGA_FRAME_HEADER = 16'haaaa;
localparam FPGA_FRAME_TAIL = 24'h00ffff;
reg [2:0]           state;
reg [7:0]           data_buf[1:0];
wire [15:0]         data_2bytes;
wire [23:0]         data_3bytes;

reg [3:0]           cnt;
reg [7:0]           cmd_data;
reg                 cmd_valid;
reg [7:0]           checksum;
reg [10:0]          data_byte_cnt;
reg [7:0]           total_length;
reg [15:0]          packet_num;
reg [10:0]          packet_length;

// Data File format
//data_file_total_length[15:0] packet_num[7:0]
/*31--------23-------15--------7-------0
 |  Total length      | pck_num        |
  --------------------------------------
  | length       |   reserved          |
*/

assign data_2bytes = {data_buf[0], data_in};
assign data_3bytes = {data_buf[1], data_buf[0], data_in};

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE_s;
        {data_buf[1], data_buf[0]} <= 'h0;
        cnt <= 'h0;
        cmd_data <= 'h0;
        cmd_valid <= 1'b0;
        checksum <= 'h0;
        data_byte_cnt <= 'h0;
        total_length <= 'h0;
        packet_num <= 'h0;
        packet_length <= 'h0;
        axis_tdata_out <= 'h0;
        axis_tvalid_out <= 1'b0;
        axis_tlast_out <= 1'b0;
        checkgood_out <= 1'b0;
        checkbad_out <= 1'b0;
    end
    else if (valid_in) begin
        data_buf[1] <= data_buf[0];
        data_buf[0] <= data_in;
        cmd_valid <= 1'b0;
        checkgood_out <= 1'b0;
        checkbad_out <= 1'b0;
        axis_tvalid_out <= 1'b0;
        axis_tlast_out <= 1'b0;
        case(state)
            IDLE_s: begin
                cnt <= 'h0;
                if (data_2bytes == FPGA_FRAME_HEADER) begin
                    state <= CMD_s;
                    checksum <= 8'haa ^ 8'haa;
                end
                else begin
                    state <= IDLE_s;
                    checksum <= 'h0;
                end
            end
            CMD_s: begin
                cmd_data <= data_in;
                if (data_in < 8'h6) begin
                    state <= DATA_s;
                    checksum <= checksum ^ data_in;
                end
                else begin
                    checksum <= checksum ^ data_in;
                    state <= DATA_FILE_s;
                    cnt <= 'h0;
                end
            end
            DATA_s: begin
                cnt <= cnt + 1'd1;
                if (data_in != {4'h0, cnt}) begin
                    state <= IDLE_s;
                end
                else if (data_in == 8'h0f) begin
                    state <= TAIL_s;
                    cnt <= 'h0;
                end
                checksum <= checksum ^ data_in;
            end
            DATA_FILE_s: begin
                checksum <= checksum ^ data_in;
                data_byte_cnt <= data_byte_cnt + 'h1;
                case(cnt)
                    4'd0: cnt <= cnt + 1'h1;
                    4'd1: begin
                        cnt <= cnt + 1'h1;
                        total_length <= data_2bytes;
                    end
                    4'd2: cnt <= cnt + 1'h1;
                    4'd3: begin
                        cnt <= cnt + 1'h1;
                        packet_num <= data_2bytes;
                    end
                    4'd4: cnt <= cnt + 1'h1;
                    4'd5: begin
                        cnt <= cnt + 1'h1;
                        packet_length <= data_2bytes[31:21];
                    end
                    4'd6: begin
                        axis_tdata_out <= data_in;
                        axis_tvalid_out <= 1'b1;
                        axis_tlast_out <= 1'b0;
                        if (data_byte_cnt == (packet_length - 1)) begin
                            axis_tlast_out <= 1'b1;
                            state <= CHECK_s;
                        end
                    end
                endcase
            end

            CHECK_s: begin
                if (checksum == data_in) begin
                    state <= TAIL_s;
                    checkgood_out <= 1'b1;
                end
                else begin
                    state <= IDLE_s;
                    checkbad_out <= 1'b1;
                end
            end
            TAIL_s: begin
                if (cnt == 4'd2 && data_3bytes == FPGA_FRAME_TAIL) begin
                    cmd_valid <= 1'b1;
                    state <= IDLE_s;
                end
                else if (cnt == 4'd3) begin
                    state <= IDLE_s;
                end
                else begin
                    cnt <= cnt + 1'd1;
                end
            end
            default: begin
                state <= IDLE_s;
            end
        endcase // cnt
    end
end

always @(*) begin
    fpga_self_check_out = 1'b0;
    srio_self_check_out = 1'b0;
    loopback422_self_check_out = 1'b0;
    lvds_ctrl_out = 1'b0;
    image_lvds_out = 1'b0;
    config_422_out = 1'b0;
    ctrl_lvds_config_out = 1'b0;
    image_lvds_config_out = 1'b0;
    com_422_test_out = 1'b0;
    srio_file_load_out = 1'b0;
    ctrl_lvds_file_out = 1'b0;
    srio_test_out = 1'b0;
    ctrl_lvds_test_out = 1'b0;
    if (cmd_valid) begin
        case (cmd_data)
            8'h01: fpga_self_check_out = 1'b1;
            8'h02: srio_self_check_out = 1'b1;
            8'h03: loopback422_self_check_out = 1'b1;
            8'h04: lvds_ctrl_out = 1'b1;
            8'h05: image_lvds_out = 1'b1;
            8'h06: config_422_out = 1'b1;
            8'h07: ctrl_lvds_config_out = 1'b1;
            8'h08: image_lvds_config_out = 1'b1;
            8'h09: com_422_test_out = 1'b1;
            8'h0a: srio_file_load_out = 1'b1;
            8'h0b: ctrl_lvds_file_out = 1'b1;
            8'hfa: srio_test_out = 1'b1;
            8'hfb: ctrl_lvds_test_out = 1'b1;
            default : begin
                fpga_self_check_out = 1'b0;
                srio_self_check_out = 1'b0;
                loopback422_self_check_out = 1'b0;
                lvds_ctrl_out = 1'b0;
                image_lvds_out = 1'b0;
                config_422_out = 1'b0;
                ctrl_lvds_config_out = 1'b0;
                image_lvds_config_out = 1'b0;
                com_422_test_out = 1'b0;
                srio_file_load_out = 1'b0;
                ctrl_lvds_file_out = 1'b0;
                srio_test_out = 1'b0;
                ctrl_lvds_test_out = 1'b0;
            end
        endcase
    end
end


assign cmd_out = cmd_data;
assign cmd_valid_out = cmd_valid;

endmodule