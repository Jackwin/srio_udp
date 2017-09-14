`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 11/09/2016 05:20:38 PM
// Design Name:
// Module Name: ip_packet_gen
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module ip_packet_gen
  #(
    parameter DEBUG = 0
    )
  (

     //Local IP and MAC
    input [31:0]        local_IP_in,
    input [47:0]        local_MAC_in,
   //ARP
   input wire [31:0]    remote_ip_addr_in,
   input wire [47:0]    remote_mac_addr_in,
   input wire           arp_reply_in,
   output               arp_reply_ack_out,

   // IP signals
   input wire           clk_32,
   input wire           reset_32,
   input wire           enable_ip_data_gen,
   input wire [7:0]     tcp_ctrl_type,
   input wire [31:0]    dest_ip_addr,
   input wire [15:0]    dest_port,

   input wire           clk_8,
   input wire           reset_8,
   output wire [7:0]    axis_tdata_out,
   output wire          axis_tvalid_out,
   output wire          axis_tlast_out,
   input wire           axis_tready_in

);

wire [31:0]          udp_data;
wire                 udp_data_valid;
wire                 udp_to_app_ready;
wire                 tcp_error;
wire                 udp_error;

wire [31:0]          tdata_32;
wire                 tvalid_32;
wire                 tlast_32;
wire [3:0]           tkeep_32;

reg [36:0]           memory[0:128];
// IP data generation data
wire [31:0]          data_gen;
reg                  data_gen_valid;
wire [3:0]           data_gen_keep;
wire                 data_gen_last;
reg [6:0]            data_cnt;
reg [15:0]           data_gen_length;
reg [1:0]            op;
reg                  enable_ip_data_gen_r;
reg                  enable_ip_data_gen_pulse;

reg [1:0]            state;
reg [5:0]            timer_cnt;


localparam DATA_IDLE = 2'd0,
  DATA_GEN = 2'd1,
  DATA_DONE = 2'd2;
  localparam data_length = 64;

always @(posedge clk_32) begin
   enable_ip_data_gen_r <= enable_ip_data_gen;
   enable_ip_data_gen_pulse <= (!enable_ip_data_gen_r & enable_ip_data_gen);
end

always @(posedge clk_32 or posedge reset_32) begin
   if (reset_32) begin
      data_cnt <= 'h0;
      state <= DATA_IDLE;
      timer_cnt <= 'h0;
      op <= 2'h2;
      data_gen_valid <= 1'b0;
   end
   else begin
      data_gen_valid <= 1'b0;
      case(state)
        DATA_IDLE: begin
            data_cnt <= 'h0;
            timer_cnt <= 'h0;
            if (enable_ip_data_gen & axis_tready_in) begin
                state <= DATA_GEN;
                op <= 'h1;
            end
            else begin
                state <= DATA_IDLE;
            end
        end
        DATA_GEN: begin
          // op <= 2'h2; // 2:Send TCP data; 1: send UDP data
            if (udp_to_app_ready) begin
                data_cnt <= data_cnt + 'h1;
            end
            data_gen_valid <= 1'b1;
             data_gen_length <= (data_length << 2);
            if (data_cnt == (data_length - 1)) begin
                state <= DATA_DONE;
            end
            else begin
                state <= DATA_GEN;
            end
        end // case: DATA_GEN
        DATA_DONE: begin
            data_gen_valid <= 1'b0;
            data_cnt <= 'h0;
            timer_cnt <= timer_cnt + 6'h1;
            if (timer_cnt == 6'h3f) begin // Delay for one certain period
                state <= DATA_IDLE;
            end
            else begin
                state <= DATA_DONE;
            end
        end // case: DATA_DONE
        default: begin
            state <= DATA_IDLE;
            data_cnt <= 'h0;
        end
      endcase // case (state)
   end // else: !if(reset_32)
end // always @ (posedge clk_32 or posedge reset_32)

assign data_gen = memory[data_cnt][31:0];
assign data_gen_keep = memory[data_cnt][35:32];
assign data_gen_last = (data_cnt == data_length);

send_top send_top_module
  (
   .clk(clk_32),
   .reset(reset_32),
   .local_IP_in         (local_IP_in),
   .local_MAC_in        (local_MAC_in),
   //ARP interface
   .remote_ip_addr_in   (remote_ip_addr_in),
   .remote_mac_addr_in  (remote_mac_addr_in),
   .arp_reply_in        (arp_reply_in),
   .arp_reply_ack_out   (arp_reply_ack_out),
   // Input data interface
   .udp_from_app_valid(data_gen_valid),
   .udp_from_app_data(data_gen),
   .udp_from_app_keep   (data_gen_keep),
   .udp_from_app_last   (data_gen_last),
   .udp_to_app_ready    (udp_to_app_ready),

   .dest_ip_addr(dest_ip_addr),
   .dest_port(dest_port),
   .data_from_app_length(data_gen_length),
   .tcp_ctrl_type(tcp_ctrl_type),

   .clk_8               (clk_8),
   .reset_8             (reset_8),
   .axis_tdata_out(axis_tdata_out),
   .axis_tvalid_out(axis_tvalid_out),
   .axis_tlast_out(axis_tlast_out),
   .axis_tready_in(axis_tready_in)
   );
/*
axis32to8 axis32to8_i (
    .clk_32(clk_32),
    .reset_32(1'b0),
    .axis_tdata_in(tdata_32),
    .axis_tvalid_in(tvalid_32),
    .axis_tkeep_in(tkeep_32),
    .axis_tlast_in(tlast_32),
    .axis_tready_out(axis_tready_out),

    .clk_8(clk_8),
    .reset_8(reset_8),
    .axis_tready_in(1'b1),
    .axis_tdata_out(axis_tdata_out),
    .axis_tvalid_out(axis_tvalid_out),
    .axis_tlast_out(axis_tlast_out)
);
*/



initial begin
   $readmemh ("data.dat", memory, 0, 128);
end
endmodule
