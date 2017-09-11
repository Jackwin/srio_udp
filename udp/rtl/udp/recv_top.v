`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 08/16/2016 08:32:54 PM
// Design Name:
// Module Name: recv_top
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

`define BROAD_ADDR 48'hffffffffffff
module recv_top
(
    input           clk_8,
    input           reset_8,
    input [47:0]    local_mac_addr,
    input [31:0]    local_ip_addr,
   // AXI stream interface
    input [7:0]     axis_tdata_in,
    input           axis_tvalid_in,
    input           axis_tlast_in,
    output          axis_tready_o,

    //ARP
    input           reply_ready_in,
    output [31:0]   remote_ip_addr_out,
    output [47:0]   remote_mac_addr_out,
    // Send out the remote ARP request
    input           arp_reply_ack_in,
    output          arp_reply_out,

    input           clk_32,
    input           reset_32,
        // UDP
    input           udpdata_tready_in,
    output [31:0]   udpdata_tdata_out,
    output [3:0]    udpdata_tkeep_out,
    output          udpdata_tvalid_out,
    output          udpdata_tfirst_out,
    output          udpdata_tlast_out,
    output [15:0]   udp_length_out

);

wire [7:0]          ip_data;
wire                ip_data_valid;
wire                ip_data_last;
wire                ip_data_ready;

wire [7:0]          arp_data;
wire                arp_data_valid;
wire                arp_data_last;


wire                udpdata_tready;
wire [7:0]          udpdata_tdata;
wire                udpdata_tvalid;
wire                udpdata_tlast;

wire [7:0]          tcp_data;
wire                tcp_valid;

recv_buffer recv_buffer_module
(
    .clk (clk_8),
    .reset (reset_8),
    .mac_addr (local_mac_addr),
    .axis_tdata_in (axis_tdata_in),
    .axis_tvalid_in (axis_tvalid_in),
    .axis_tlast_in (axis_tlast_in),
    .axis_tready_o (axis_tready_o),

    .arp_axis_tready_in     (1'b1),
    .arp_axis_tdata_out (arp_data),
    .arp_axis_tvalid_out (arp_data_valid),
    .arp_axis_tlast_out (arp_data_last),

    .ip_axis_tready_in  (ip_data_ready),
    .ip_axis_tdata_out (ip_data),
    .ip_axis_tvalid_out (ip_data_valid),
    .ip_axis_tlast_out (ip_data_last)
);

udp_rcv udp_rcv_module
(
    .clk(clk_8),
    .reset              (reset_8),
    .udp_axis_tdata_in (ip_data),
    .udp_axis_tvalid_in (ip_data_valid),
    .udp_axis_tlast_in  (ip_data_last),
    .udp_axis_tready_out(ip_data_ready),

    .udpdata_tready_in  (udpdata_tready),
    .udpdata_tdata_out  (udpdata_tdata),
    .udpdata_tvalid_out (udpdata_tvalid),
    .udpdata_tlast_out  (udpdata_tlast)
);

arp_recv arp_recv_module
(
    .clk (clk_8),
    .reset              (reset_8),
    .arp_tdata_in       (arp_data),
    .arp_tvalid_in      (arp_data_valid),
    .arp_tlast_in       (arp_data_last),
    .local_ip_addr      (local_ip_addr),

    .reply_ready_in     (reply_ready_in),
    .remote_ip_addr_out (remote_ip_addr_out),
    .remote_mac_addr_out(remote_mac_addr_out),
    .arp_reply_ack      (arp_reply_ack_in),
    .arp_reply_out      (arp_reply_out)

);
udp_forward udp_forward_module
(
    .clk                (clk_8),
    .reset              (reset_8),
    .udp_axis_tdata_in  (udpdata_tdata),
    .udp_axis_tvalid_in (udpdata_tvalid),
    .udp_axis_tlast_in  (udpdata_tlast),
    .udp_axis_tready_out(udpdata_tready),

    .clk_32             (clk_32),
    .reset_32           (reset_32),
    .udp_axis_tready_in (udpdata_tready_in),
    .udp_axis_tdata_out (udpdata_tdata_out),
    .udp_axis_tfirst_out(udpdata_tfirst_out),
    .udp_axis_tvalid_out(udpdata_tvalid_out),
    .udp_axis_tkeep_out (udpdata_tkeep_out),
    .udp_axis_tlast_out (udpdata_tlast_out),
    .udp_length_out     (udp_length_out)
);

endmodule
