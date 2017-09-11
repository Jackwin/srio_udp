
//states
//`define IDLE_s     2'h0
//`define ARP_RECV_s 2'h1
//`define IP_RECV_s  2'h2
//`define END_s      2'h3

//types
`define NONE     2'h0
`define ARP_TYPE 2'h1
`define IP_TYPE  2'h2

`define IDLE    2'h0
`define DES_MAC 2'h1
`define SRC_MAC 2'h2
`define PRTC 2'h3

// protocol
`define ARP_PRTC 16'h0806
`define IP_PRTC 16'h0800
`define RARP_PRTC 16'h8035
module recv_buffer
(
    input           clk,
    input           reset,
    input [47:0]    mac_addr,

    //input port
    input [7:0]     axis_tdata_in,
    input           axis_tvalid_in,
    input           axis_tlast_in,
    output          axis_tready_o,

    // Output ports
    input           arp_axis_tready_in,
    output reg [7:0] arp_axis_tdata_out,
    output reg      arp_axis_tvalid_out,
    output reg      arp_axis_tlast_out,
    // ARP request from remote
    output reg      arp_request_out,

    input           ip_axis_tready_in,
    output reg [7:0] ip_axis_tdata_out,
    output reg      ip_axis_tvalid_out,
    output reg      ip_axis_tlast_out
);

localparam           IDLE_s = 3'h0;
localparam           MAC_s = 3'd1;
localparam           WAIT_s = 3'd2;
localparam           IP_RECV_HEADER_s = 3'd3;
localparam           IP_RECV_s = 3'd4;
localparam           ARP_RECV_s = 3'd5;
localparam           END_s = 3'd6;
localparam           BUF_DEPTH = 6;

reg [2:0]            state;
reg [1:0]            recv_state;

//reg [7:0]            data_buf[0:BUF_DEPTH-1];
reg [7:0]           data_buf4, data_buf3, data_buf2, data_buf1, data_buf0;
wire [47:0]       data_6bytes;
wire [15:0]       data_2bytes;


reg [15:0]           ip_length, byte_cnt;
reg                  next_state_IP;
reg                  next_state_ARP;

// Input signals
reg [5:0]            header_len_reg;
reg [5:0]            header_cnt;
integer              k;

// timer signals
reg                 mac_timer_ena;
reg                 mac_timer_out;

reg                 wait_timer_ena;
reg                 wait_timer_out;

reg                 timer_ena;
wire                timer_out;
reg                 timer_reset;

//assign axis_tready_o = 1'b1;
assign axis_tready_o = arp_axis_tready_in || ip_axis_tready_in;

always @(posedge clk) begin
    if (reset) begin
        data_buf4 <= 'h0;
        data_buf3 <= 'h0;
        data_buf2 <= 'h0;
        data_buf1 <= 'h0;
        data_buf0 <= 'h0;
    end
    else begin
        if (axis_tvalid_in) begin
            data_buf4 <= data_buf3;
            data_buf3 <= data_buf2;
            data_buf2 <= data_buf1;
            data_buf1 <= data_buf0;
            data_buf0 <= axis_tdata_in;
        end
    end
end
assign data_6bytes = {data_buf4, data_buf3, data_buf2,
                     data_buf1, data_buf0, axis_tdata_in};

assign data_2bytes = {data_buf0, axis_tdata_in};

always @(posedge clk) begin
    if (reset) begin
         ip_axis_tdata_out <= 32'h0;
         ip_axis_tvalid_out <= 1'b0;
         ip_axis_tlast_out <= 1'b0;
         arp_axis_tdata_out <= 32'h0;
         arp_axis_tvalid_out <= 1'b0;
         arp_axis_tlast_out <= 1'b0;
         arp_request_out <= 1'b0;
         state <= IDLE_s;
         ip_length <= 'h0;
         byte_cnt <= 'h0;

         header_len_reg <= 'h0;
         next_state_ARP <= 1'b0;
         next_state_IP <= 1'b0;
         timer_ena <= 1'b0;
         timer_reset <= 1'b1;
      end
    else begin
        timer_ena <= 1'b0;
        timer_reset <= 1'b0;
        if (timer_out) begin
            state <= IDLE_s;
            timer_reset <= 1'b1;
        end

         case(state)
            IDLE_s: begin
                byte_cnt <= 'h0;
                ip_axis_tlast_out <= 1'b0;
                arp_axis_tlast_out <= 1'b0;
                if ((data_6bytes == mac_addr || data_6bytes == 48'hffffffffffff) && axis_tvalid_in) begin
                    state <= MAC_s;
                end
                else begin
                    state <= IDLE_s;
                end
            end
            // TODO: Set up timer  constraint data_2byte and data_6byte
            MAC_s: begin
                timer_ena <= 1'b1;
                if (data_2bytes == `IP_PRTC && axis_tvalid_in) begin
                    $display("IP package found.\n");
                    next_state_IP <= 1'b1;
                    state <= IP_RECV_HEADER_s;
                    timer_reset <= 1'b1;
                    byte_cnt <= 'h0;
                end
                else if (data_2bytes == `ARP_PRTC && axis_tvalid_in) begin
                    $display("ARP package found");
                    next_state_ARP <= 1'b1;
                    state <= ARP_RECV_s;
                    timer_reset <= 1'b1;
                    byte_cnt <= 'h0;
                end
                else begin
                    state <= MAC_s;
                end

            end
            WAIT_s: begin
                timer_ena <= 1'b1;
                if (axis_tvalid_in) begin
                    byte_cnt <= byte_cnt + 1'h1;
                end
                if (byte_cnt == 'd27 && next_state_IP) begin
                    state <= IP_RECV_s;
                    byte_cnt <= 'h0;
                    timer_reset <= 1'b1;
                end
                else if (byte_cnt == 'd27 && next_state_ARP) begin
                    state <= ARP_RECV_s;
                    byte_cnt <= 'h0;
                    timer_reset <= 1'b1;
                end
                else begin
                    state <= WAIT_s;

                end

            end
            IP_RECV_HEADER_s: begin
                timer_ena <= 1'b1;
                if(byte_cnt == (header_len_reg - 1'd1) && header_len_reg != 'h0) begin
                    state <= IP_RECV_s;
                    timer_reset <= 1'b1;
                end
                else if (axis_tvalid_in) begin
                    byte_cnt <= byte_cnt + 1'h1;
                end
                else begin
                    byte_cnt <= byte_cnt;
                end

                if (byte_cnt == 0 && axis_tvalid_in) begin
                    header_len_reg <= (axis_tdata_in[3:0] << 2);
                end
                else begin
                    header_len_reg <= header_len_reg;
                end
                if (byte_cnt == 3 && axis_tvalid_in) begin
                    $display("The total length of IP package is %d.\n", data_2bytes);
                    ip_length <= data_2bytes;
                end
                else begin
                    ip_length <= 'h0;
                end
            end
            IP_RECV_s: begin
                timer_ena <= 1'b1;
                ip_axis_tdata_out <= axis_tdata_in;
                ip_axis_tvalid_out <= axis_tvalid_in;
                ip_axis_tlast_out <= axis_tlast_in;
                if (axis_tlast_in) begin
                    state <=END_s;
                    timer_reset <= 1'b1;
                end
                else begin
                    state <= IP_RECV_s;
                    timer_reset <= 1'b1;
                end

            end
            ARP_RECV_s: begin
                timer_ena <= 1'b1;
                arp_axis_tdata_out <= axis_tdata_in;
                arp_axis_tvalid_out <= axis_tvalid_in;
                arp_axis_tlast_out <= axis_tlast_in;
                if (axis_tlast_in) begin
                    state <=END_s;
                    timer_reset <= 1'b1;
                end
                else begin
                    state <= ARP_RECV_s;
                end
            end
            END_s: begin
                ip_axis_tlast_out <= 1'b0;
                ip_axis_tvalid_out <= 1'b0;
                arp_axis_tlast_out <= 1'b0;
                arp_axis_tvalid_out <= 1'b0;
                next_state_ARP <= 1'b0;
                next_state_IP <= 1'b0;
                byte_cnt <= 'h0;
                state <= IDLE_s;
            end
            default: begin
                state <= IDLE_s;
            end
        endcase // state
    end
end


timer #(
.TIMER_WIDTH(12)
    )
timer_i
(
    .clk (clk),
    .reset(timer_reset),
    .enable(timer_ena),
    .timer_out(timer_out)
);


wire [0:0] arp_tvalid_ila;
wire [0:0] arp_tlast_ila;
wire [0:0] arp_reply_ila;
wire [0:0] axis_tvalid_ila;
assign arp_tvalid_ila[0] = arp_axis_tvalid_out;
assign arp_tlast_ila[0] = arp_axis_tlast_out;
assign axis_tvalid_ila[0] = axis_tvalid_in;
//assign arp_reply_ila[0] = arp_reply_r;

ila_recv_buf ila_recv_top (
        .clk(clk), // input wire clk
        .probe0(arp_axis_tdata_out), // input wire [7:0]  probe0
        .probe1(arp_tvalid_ila), // input wire [0:0]  probe1
        .probe2(arp_tlast_ila), // input wire [0:0]  probe2
        .probe3(axis_tvalid_ila), // input wire [0:0]  probe3
        .probe4(state),
        .probe5(byte_cnt),
        .probe6(data_6bytes),
        .probe7(data_2bytes)
    );
endmodule
