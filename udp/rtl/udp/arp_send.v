`timescale 1ns / 1ps

/*************************
arp_send.v

Generates ARP packets based on IP and MAC addresses that need to be sent.

Inputs:
clk
reset
send_ip_addr_reply (from arp_rcv)
send_mac_addr_reply (from arp_rcv)
send_ip_addr_request (from send_buffer)
SPA (from ip_send)
SHA (from ip_send)
request_en (a bit that is high if a request needs to be sent)
reply_en (a bit that is high if a reply needs to be sent)
send_buffer_ready (enables sending of ARP packets to the send_buffer module)

Outputs:
arp_valid (to send_buffer)
arp_data (to send_buffer)
reply_ready_out (to arp_rcv)
request_ready (to send_buffer)
arp_mac_addr (to send_buffer)


**************************/
`define REQUEST    16'h0001
`define REPLY    16'h0002
module arp_send(
    input               clk,
    input               reset,
    // The remote machine's IP and MAC
    input [31:0]        remote_ip_addr_in,
    input [47:0]        remote_mac_addr_in,
    // The ip address that ARP will request for.
    input [31:0]        ip_addr_request_in,
    input [31:0]        SPA_in,
    input [47:0]        SHA_in,
    input               request_en_in,
    output reg          request_ack_out,
    input               reply_en_in,
    output reg          reply_ack_out,
    input               send_buffer_ready_in,

    output reg [31:0]   arp_tdata_out,
    output reg          arp_tvalid_out,
    output reg [3:0]    arp_tkeep_out,
    output reg          arp_tlast_out,

    output              reply_ready_out,
    output              request_ready_out,
    output reg [47:0]   arp_mac_addr_out
);

reg [2:0]               word_counter;         //increments when ARP data is being received in 7 separate 32-bit words
reg [15:0]              HTYPE, PTYPE, OPER;   // HTYPE : hardware type; PTYPE: protocol type
reg [7:0]               HLEN, PLEN;
reg [47:0]              THA;    // target MAC address
reg [31:0]              TPA;   // target IP address
reg                     request_buffer_valid, reply_buffer_valid, clear_to_send;
reg [31:0]              ip_request_buffer, ip_reply_buffer;
reg [47:0]              mac_reply_buffer;
reg                     reply_en_r1, reply_en_r2;
reg                     request_en_r1, request_en_r2;


//only ready for new packets when buffers do not have valid data in them
assign request_ready_out = ~request_buffer_valid;
assign reply_ready_out = ~reply_buffer_valid;

//CDR

always @(posedge clk) begin
    reply_en_r1 <= reply_en_in;
    reply_en_r2 <= reply_en_r1;

    request_en_r1 <= request_en_in;
    request_en_r2 <= request_en_r1;
end

always @(posedge clk) begin
    if (reset) begin
        // initialization
        word_counter <= 3'd0;
        HTYPE <= 16'h0001;
        PTYPE <= 16'h0800;
        HLEN <= 8'h06;
        PLEN <= 8'h04;
        OPER <= 16'h0;
        THA <= 48'h0;
        TPA <= 32'h0;
        clear_to_send <= 1'b0;
        request_buffer_valid <= 1'b0;
        reply_buffer_valid <= 1'b0;
        ip_request_buffer <= 32'b0;
        ip_reply_buffer <= 32'b0;
        mac_reply_buffer <= 32'b0;
        arp_mac_addr_out <= 48'b0;
        arp_tvalid_out <= 1'b0;
        arp_tdata_out <= 32'b0;
        arp_tlast_out <= 1'b0;
        arp_tkeep_out <= 'h0;
        request_ack_out <= 1'b0;
        reply_ack_out <= 1'b0;
    end
    else  begin
         case ({request_en_r2, reply_en_r2})
            2'b00: begin
            //check the buffers for data
                reply_ack_out <= 1'b0;
                request_ack_out <= 1'b0;
                if ((send_buffer_ready_in) && (!clear_to_send) && (!arp_tvalid_out)) begin
                    if (request_buffer_valid) begin
                        OPER <= `REQUEST;
                        TPA <= ip_request_buffer;
                        THA <= 48'h0;
                        request_buffer_valid <= 1'b0;
                        clear_to_send <= 1'b0;
                        //request_ack_out <= 1'b1;
                    end
                    else if ((reply_buffer_valid) && (!request_buffer_valid)) begin
                        OPER <= `REPLY;
                        TPA <= ip_reply_buffer;
                        THA <= mac_reply_buffer;
                        reply_buffer_valid <= 1'b0;
                        clear_to_send <= 1'b0;
                       // reply_ack_out <= 1'b1;
                    end
                end
                else begin
                    clear_to_send <= 1'b0;
                end
            end
            2'b01: begin
                if ((send_buffer_ready_in) && (!clear_to_send) && (!arp_tvalid_out)) begin
                    OPER <= `REPLY;
                    TPA <= remote_ip_addr_in;
                    THA <= remote_mac_addr_in;
                    clear_to_send <= 1'b1;
                    reply_ack_out <= 1'b1;
                end
                else begin
                    ip_reply_buffer <= remote_ip_addr_in;
                    reply_buffer_valid <= 1'b1;
                    mac_reply_buffer <= remote_mac_addr_in;
                    clear_to_send <= 1'b0;
                    reply_ack_out <= 1'b0;
                end
            end
            2'b10: begin
                if ((send_buffer_ready_in) && (!clear_to_send) && (!arp_tvalid_out)) begin
                    OPER <= `REQUEST;
                    TPA <= ip_addr_request_in;
                    THA <= 48'h0;
                    clear_to_send <= 1'b1;
                    request_ack_out <= 1'b1;
                    end
                else begin
                   ip_request_buffer <= ip_addr_request_in;
                   request_buffer_valid <= 1'b1;
                   clear_to_send <= 1'b0;
                   request_ack_out <= 1'b0;
                end
            end
            2'b11: begin
                if ((send_buffer_ready_in) && (!clear_to_send) && (!arp_tvalid_out)) begin
                    OPER <= `REQUEST;
                    TPA <= ip_addr_request_in;
                    THA <= 48'h0;
                    clear_to_send <= 1'b1;
                    request_ack_out <= 1'b1;
                end
                else begin
                    ip_request_buffer <= ip_addr_request_in;
                    request_buffer_valid <= 1'b1;
                    clear_to_send <= 1'b0;
                    request_ack_out <= 1'b0;
                end
                ip_reply_buffer <= remote_ip_addr_in;
                reply_buffer_valid <= 1'b1;
                mac_reply_buffer <= remote_mac_addr_in;
            end
           default:
             begin

             end
         endcase
            //Data Tx state machine:
         //send out ARP packets one word at a time when send_buffer_ready_in is high,
     //and set the valid bit high when doing so.  increment through the
     //words using word_counter.
            if (send_buffer_ready_in) begin
                case (word_counter)
                    3'd0: begin
                        if (clear_to_send) begin //packet is beginning to be sent
                            arp_tdata_out <= {HTYPE, PTYPE};
                            arp_tvalid_out <= 1'b1;
                            arp_tkeep_out <= 'hf;
                            arp_tlast_out <= 1'b0;
                            word_counter <= word_counter + 1;
                            clear_to_send <= 1'b0;

                            //In the ARP request, the destination MAC is FFFFFFFFFFFF
                            if (OPER == `REQUEST) begin
                                arp_mac_addr_out <= 48'hFFFFFFFFFFFF;
                            end
                            else begin
                                arp_mac_addr_out <= THA;
                            end
                        end
                        else begin //packet just finished being sent... now we wait for another clear_to_send
                            arp_tvalid_out <= 1'b0;
                            arp_tlast_out <= 1'b0;
                        end
                    end
                    3'd1: begin
                        arp_tdata_out <= {HLEN, PLEN, OPER}; // hardware address length, protocal addr length, operation type
                        arp_tvalid_out <= 1'b1;
                        arp_tkeep_out <= 'hf;
                        arp_tlast_out <= 1'b0;
                        word_counter <= word_counter + 1;
                    end
                    3'd2: begin
                        arp_tdata_out <= SHA_in[47:16];
                        arp_tvalid_out <= 1'b1;
                        arp_tkeep_out <= 'hf;
                        arp_tlast_out <= 1'b0;
                        word_counter <= word_counter + 1;
                    end
                    3'd3: begin
                        arp_tdata_out <= {SHA_in[15:0], SPA_in[31:16]};
                        arp_tvalid_out <= 1'b1;
                        arp_tkeep_out <= 'hf;
                        arp_tlast_out <= 1'b0;
                        word_counter <= word_counter + 1;
                    end
                    3'd4: begin
                        arp_tdata_out <= {SPA_in[15:0], THA[47:32]};
                        arp_tvalid_out <= 1'b1;
                        arp_tkeep_out <= 'hf;
                        arp_tlast_out <= 1'b0;
                        word_counter <= word_counter + 1;
                    end
                    3'd5: begin
                        arp_tdata_out <= THA[31:0];
                        arp_tvalid_out <= 1'b1;
                        arp_tkeep_out <= 'hf;
                        arp_tlast_out <= 1'b1;
                        word_counter <= word_counter + 1;
                    end
                    3'd6: begin
                        arp_tdata_out <= TPA;
                        arp_tvalid_out <= 1'b1;
                        arp_tkeep_out <= 'hf;
                        arp_tlast_out <= 1'b1;
                        word_counter <= 3'd0;
                    end
                    default: begin
                        arp_tdata_out <= 32'b0;
                        arp_tvalid_out <= 1'b0;
                        arp_tkeep_out <= 'h0;
                        arp_tlast_out <= 1'b0;
                        word_counter <= 3'd0;
                    end
                endcase

            end
            else begin
                arp_tdata_out <= 'h0;
                arp_tvalid_out <= 1'b0;
                arp_tkeep_out <= 'h0;
                arp_tlast_out <= 1'b0;
            end
        end
   end

endmodule

