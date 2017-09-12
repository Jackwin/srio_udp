`timescale 1ns/1ps

module srio_udp_tb ();

reg             clk_32;
reg             reset_32, reset_srio;
reg             enable_pat_gen;
reg             clk_8, clk_srio;
reg [1:0]       op;
reg [7:0]       tcp_ctrl_type;
reg [31:0]      dest_ip_addr = 32'hddccbbaa;
reg [15:0]      dest_port = 32'd1024;
reg [31:0]      remote_ip_addr = 32'hddccbbaa;
reg [47:0]      remote_mac_addr = 48'hdd0504030201;

wire [31:0]     local_ip_addr = 32'hddccbbaa;
reg             arp_reply;

reg             aclk;
reg             areset;

wire [7:0]      tdata;
wire [7:0]      tkeep;
wire            tvalid;
wire            tlast;
wire            tcp_error_out;
wire            udp_error_out;

wire            reply_ready_in = 1'b1;;
wire [31:0]     remote_ip_addr_out;
wire [47:0]     remote_mac_addr_out;
wire            arp_reply_out;
wire            arp_reply_ack;

wire            udpdata_tready_in ;
wire [31:0]     udpdata_tdata_out;
wire            udpdata_tvalid_out;
wire [3:0]      udpdata_tkeep_out;
wire            udpdata_tfirst_out;
wire            udpdata_tlast_out;
wire [15:0]     udpdata_length_out;

wire            srio_ready_in;
wire [15:0]     srio_length_out;
wire [63:0]     srio_data_out;
wire            srio_valid_out;
wire            srio_first_out;
wire [7:0]      srio_keep_out;
wire            srio_last_out;

initial begin
    clk_32 = 1'b0;
    forever
        #16 clk_32 = ~clk_32;
end

initial begin
    clk_8 = 1'b0;
    forever
        #4 clk_8 = ~clk_8;
end

initial begin
    clk_srio = 1'b0;
    forever
        #32 clk_srio = ~clk_srio;
end

initial begin
    reset_32 = 1'b1;
    #100 reset_32 = 1'b0;
end

initial begin
    reset_srio = 1'b1;
    #120 reset_srio = 1'b0;
end

initial begin
    aclk = 1'b0;
    forever
    #10 aclk = ~aclk;
end

initial begin
    areset = 1'b1;
    #100 areset = 1'b0;
end

initial begin
    op = 'h0;
    arp_reply = 1'b0;
    enable_pat_gen = 1'b0;
    tcp_ctrl_type = 'h0;
    #500;
    @(posedge clk_32);
    op = 'h1;
    enable_pat_gen = 1'b1;
    @(posedge clk_32);
    @(posedge clk_32);
    op = 'h0;
    enable_pat_gen = 1'b0;
    #3000;
    @(posedge clk_32);
    arp_reply = 1'b1;
    @(posedge clk_32);
    arp_reply = 1'b0;
    #30000;
    $stop;
end // initial begin
/*
initial begin
    udpdata_tready_in = 1'b1;
    #3000;
    @(posedge clk_32);
    udpdata_tready_in <= 1'b0;
    @(posedge clk_32);
    udpdata_tready_in = 1'b1;
end
*/
ip_packet_gen ip_packet_gen_module
(

    // IP signals
    .clk_32(clk_32),
    .reset_32(reset_32),
    .enable_ip_data_gen(enable_pat_gen),
    .tcp_ctrl_type(tcp_ctrl_type),
    .dest_ip_addr(dest_ip_addr),
    .dest_port(dest_port),

    //ARP
    .remote_ip_addr_in (remote_ip_addr),
    .remote_mac_addr_in(remote_mac_addr),
    //TODO: solve CDC
    .arp_reply_in(arp_reply || arp_reply_out),
    .arp_reply_ack_out (arp_reply_ack),

    .aclk(aclk),
    .areset(areset),
    .clk_8(clk_8),
    .axis_tdata_out(tdata),
    .axis_tvalid_out(tvalid),
    .axis_tlast_out(tlast),
    .axis_tready_in(1'b1)
);


recv_top recv_top_i
(
    .clk_8(clk_8),
    .reset_8        (areset),
    .local_mac_addr     (remote_mac_addr),
    .local_ip_addr      (local_ip_addr),

    .axis_tdata_in(tdata),
    .axis_tvalid_in(tvalid),
    .axis_tlast_in(tlast),
    .axis_tready_o(axis_tready_o),

    .reply_ready_in     (reply_ready_in),
    .remote_ip_addr_out (remote_ip_addr_out),
    .remote_mac_addr_out(remote_mac_addr_out),
    //TODO add arp_reply_ack
    .arp_reply_ack_in   (arp_reply_ack),
    .arp_reply_out (arp_reply_out),

    .clk_32             (clk_32),
    .reset_32           (reset_32),
    .udpdata_tready_in  (udpdata_tready_in),
    .udpdata_tdata_out  (udpdata_tdata_out),
    .udpdata_tfirst_out (udpdata_tfirst_out),
    .udpdata_tvalid_out (udpdata_tvalid_out),
    .udpdata_tkeep_out  (udpdata_tkeep_out),
    .udpdata_tlast_out  (udpdata_tlast_out),
    .udp_length_out     (udpdata_length_out)

);

udp2srio_interface udp2srio_interface_i
(
    .clk_udp        (clk_32),
    .reset_udp      (reset_32),
    .udp_data_in    (udpdata_tdata_out),
    .udp_valid_in   (udpdata_tvalid_out),
    .udp_first_in   (udpdata_tfirst_out),
    .udp_keep_in    (udpdata_tkeep_out),
    .udp_last_in    (udpdata_tlast_out),
    .udp_length_in  (udpdata_length_out),
    .udp_ready_out  (udpdata_tready_in),

    .clk_srio      (clk_srio),
    .reset_srio    (reset_srio),
    .nwr_req_out     (nwr_req_out),
    .srio_ready_in  (srio_ready_in),
    .srio_length_out(srio_length_out),
    .srio_data_out (srio_data_out),
    .srio_valid_out(srio_valid_out),
    .srio_first_out(srio_first_out),
    .srio_keep_out (srio_keep_out),
    .srio_last_out (srio_last_out)

    );

input_reader input_reader_i
(
    .clk             (clk_srio),
    .reset           (reset_srio),

    .data_in         (srio_data_out),
    .data_valid_in   (srio_valid_out),
    .data_first_in   (srio_first_out),
    .data_keep_in    (srio_keep_out),
    .data_len_in     (srio_length_out),
    .data_last_in    (srio_last_out),
    .data_ready_out  (user_tready_out),
    .ack_o           (ack_o),

    .output_tready_in(user_tready),
    .output_tdata    (user_tdata),
    .output_tvalid   (user_tvalid),
    .output_tkeep    (user_tkeep),
    .output_data_len (user_tsize),
    .output_tlast    (user_tlast),
    .output_tfirst   (user_tfirst),
    .output_done     ()

    );


endmodule