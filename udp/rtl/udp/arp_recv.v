`timescale 1ns/1ps

module arp_recv (
    input               clk,
    input               reset,

    input [7:0]         arp_tdata_in,
    input               arp_tvalid_in,
    input               arp_tlast_in,

    input [31:0]        local_ip_addr,

    input               reply_ready_in,
    output reg [31:0]   remote_ip_addr_out,
    output reg [47:0]   remote_mac_addr_out,
    // Send out the remote ARP request
    input               arp_reply_ack,
    output              arp_reply_out

);
localparam              BUF_DEPTH = 9;
localparam              ARP_LENGTH = 28;
reg [7:0]               data_buf[0: BUF_DEPTH-1];

reg [4:0]               byte_cnt;
reg                     arp_reply_r;
reg                     arp_reply_ack_r1, arp_reply_ack_r2;
wire [31:0]             des_ip;

integer k;

//Clock domain cross

always @(posedge clk) begin
    arp_reply_ack_r1 <= arp_reply_ack;
    arp_reply_ack_r2 <= arp_reply_ack_r1;
end

always @(posedge clk) begin
    if (reset) begin
        for (k = 0; k < BUF_DEPTH; k = k + 1) begin
            data_buf[k] <= 'h0;
        end
    end
    else begin
        if (arp_tvalid_in) begin
            for (k = 0; k < (BUF_DEPTH - 1); k = k + 1) begin
                data_buf[k + 1] <= data_buf[k];
            end
            data_buf[0] <= arp_tdata_in;
        end
        else begin
            for (k = 0; k < (BUF_DEPTH - 1); k = k + 1) begin
                data_buf[k] <= data_buf[k];
            end
        end
    end
end

always @(posedge clk) begin
    if (reset) begin
        byte_cnt <= 'h0;
    end
    else begin
        if (arp_reply_out || byte_cnt == (ARP_LENGTH - 1)) begin
            byte_cnt <= 'h0;
        end
        else if (arp_tvalid_in && ~arp_tlast_in) begin
            byte_cnt <= byte_cnt + 5'd1;
        end
        else if (arp_tlast_in) begin
            byte_cnt <= 'h0;
        end
        else begin
            byte_cnt <= byte_cnt;
        end
    end
end

assign des_ip = {data_buf[2], data_buf[1], data_buf[0], arp_tdata_in};

always @(posedge clk) begin
    if (reset) begin
        remote_mac_addr_out <= 'h0;
        remote_ip_addr_out <= 'h0;
        arp_reply_r <= 1'b0;
    end
    else begin
        remote_ip_addr_out <= remote_ip_addr_out;
        remote_mac_addr_out <= remote_mac_addr_out;
        // Register the remote IP and MAC, used in the ARP reply operation.
        if (arp_tvalid_in && byte_cnt == 5'd17 ) begin
            remote_mac_addr_out <= {data_buf[8], data_buf[7], data_buf[6], data_buf[5],
                                data_buf[4], data_buf[3]};
            remote_ip_addr_out <= {data_buf[2], data_buf[1], data_buf[0], arp_tdata_in};
        end
        if (arp_tvalid_in && byte_cnt == 5'd27) begin
            // Filter the local_ip_address and generate ARP reply operation
            if (des_ip == local_ip_addr) begin
                arp_reply_r <= 1'b1;
            end
            else begin
                arp_reply_r <= 1'b0;
            end
        end
        else if (reply_ready_in && arp_reply_ack_r2)begin
            arp_reply_r <= 1'b0;
        end
        else begin
            arp_reply_r <= arp_reply_r;
        end
    end
end

assign arp_reply_out = reply_ready_in ? arp_reply_r : 1'b0;

wire [0:0] arp_tvalid_ila;
wire [0:0] arp_tlast_ila;
wire [0:0] arp_reply_ila;
assign arp_tvalid_ila[0] = arp_tvalid_in;
assign arp_tlast_ila[0] = arp_tlast_in;
assign arp_reply_ila[0] = arp_reply_r;

ila_arp ila_arp (
        .clk(clk), // input wire clk
        .probe0(des_ip),
        .probe1(byte_cnt),
        .probe2(arp_reply_ila),
        .probe3(arp_tdata_in),
        .probe4(arp_tvalid_ila),
        .probe5(arp_tlast_ila),
        .probe6(arp_reply_ila)
    );

endmodule