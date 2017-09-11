`timescale 1ps/1ps
`define INIT 2'h0 //all
`define RECV 2'h1 //ri, ra
`define MAC  2'h1 //trans
`define IP   2'h1 //cpu
`define WAIT 2'h2 //ri, ra, trans
`define ARP  2'h2
`define REQ  2'h3 //trans


module send_mac
#(
    parameter SRC_MAC = 48'h55ffeeddccbb,
    parameter DES_MAC = 48'hdd0504030201
    )
(

    input               clk,
    input               reset,
    //ip send
    input [31:0]        axis_tdata_in,
    input               axis_tvalid_in,
    input [3:0]         axis_tkeep_in,
    input               axis_tlast_in,
    output reg          axis_tready_out,
    //arp_send

    //**send request ports
    input               req_ready,
    output reg [31:0]   arp_send_ip_addr,
    output reg          req_en,
    //mac_cache
    input [47:0]        r_mac_addr,
    output reg          r_mac_cache_en,
    output reg [31:0]   r_mac_cache_ip_addr,

    output reg [31:0]   tdata,
    output reg          tvalid,
    output reg [3:0]    tkeep,
    output reg          tlast,
    input               tready
);

reg                 tvalid_r = 1'b0;
reg                 tlast_r = 1'b0;
reg [3:0]           tkeep_r = 4'h0;
reg [1:0]           tail_cnt;



//ip vars
reg [31:0]          data_r1, data_r2, data_r3 ='h0;
reg [3:0]           keep_r1, keep_r2, keep_r3;
reg                 last_r1, last_r2, last_r3;
reg                 valid_r1, valid_r2, valid_r3;

reg [3:0]           data_keep_r1, data_keep_r2;
reg                 data_last_r1, data_last_r2;
reg                 data_valid_r1, data_valid_r2;

reg [31:0]          data_r1, data_r2;
reg                 data_valid_r;
reg                 ip_head;
reg [1:0]           buffer_cnt;
reg                 data_symbol;

//translation vars
reg [1:0]               mac_state;
reg [15:0]               mac_timeout;

integer               i;

reg[1:0]            state;

//receive ip state machine
always @(posedge clk or posedge reset) begin
  if(reset) begin
     data_ready <= 1'b1;
     ri_buf_translate <= 1'b0;
     ip_head <= 'b1;
     arp_head <= 'b1;
     data_symbol <= 'b0;
     arp_send_symbol <= 'b0;
     buffer_cnt <= 'h0;
     tail_cnt <= 'h0;
     arp_send_valid_r <= 1'b0;
     {data_keep_r2, data_keep_r1} <= 'h0;
     {data_last_r2, data_last_r1} <= 'h0;
     {data_valid_r2, data_valid_r1} <= 'h0;
     {keep_r3, keep_r2, keep_r1} <= 'h0;
     {last_r3, last_r2, last_r1} <= 'h0;
     for(i = 8'h0; i < 8'hFF; i = i+1)
       ri_data[i] <= 32'h0;
  end else
    begin
       tdata <= data_r3;
       data_r3 <= data_r2;
       data_r2 <= data_r1;

       tkeep <= keep_r3;
       keep_r3 <= keep_r2;
       keep_r2 <= keep_r1;

       tvalid <= valid_r3;
       valid_r3 <= valid_r2;
       valid_r2 <= valid_r1;

       tlast <= last_r3;
       last_r3 <= last_r2;
       last_r2 <= last_r1;

       ip_data_r1 <= data_data;
       ip_data_r2 <= ip_data_r1;

       data_valid_r1 <= data_valid;
       data_valid_r2 <= data_valid_r1;

       data_keep_r1 <= data_keep;
       data_keep_r2 <= data_keep_r1;

       data_last_r1 <= data_last;
       data_last_r2 <= data_last_r1;

       tlast_r <= 1'b0;

       case (state)
         `INIT: begin
            tail_cnt <= 'h0;
            if (axis_tvalid_in & tready) begin
               data_r3 <= DES_MAC[47:16];
               data_r2 <= {DES_MAC[15:0], SRC_MAC[47:32]};
               data_r1 <= SRC_MAC[31:0];
               keep_r3 <= 'hf;
               keep_r2 <= 'hf;
               keep_r1 <= 'hf;
               {valid_r3, valid_r2, valid_r1} <= 3'b111;
               {last_r3, last_r2, last_r1} <= 3'b000;
               // ip_data_r1 <= data_data;
               ip_head <= 1'b1;
               state <= `RECV;
            end // if (data_valid)
            else begin
               state <= `INIT;
               tvalid_r <= 1'b0;
               tkeep_r <= 4'h0;

            end // else: !if(arp_send_valid)
         end
         `RECV: begin
          // TODO: align with ethernet frame
            if (data_valid_r1) begin
               data_symbol <= 'b1;
               if (ip_head) begin
                  data_r1 <= {16'h0800, ip_data_r1[31:16]};
                  keep_r1 <= {2'b11, data_keep_r1[3:2]};
                  last_r1 <= 1'b0;
                  valid_r1 <= 1'b1;
                  ip_head <= 1'b0;
               end
               else begin
                  data_r1 <= {ip_data_r2[15:0], ip_data_r1[31:16]};
                  keep_r1 <= {data_keep_r2[1:0], data_keep_r1[3:2]};
                  last_r1 <= 1'b0;
                  valid_r1 <= data_valid_r2 | data_valid_r1;
                  buffer_cnt <= 'h1;
               end
            end
            else if (!data_valid_r1 && arp_send_valid_r) begin
               arp_send_symbol <= 1'b1;
               if (arp_head) begin
                  data_r1 <= {16'h0806, arp_data_r1[31:16]};
                  keep_r1 <= {2'b11, arp_send_keep_r1[3:2]};
                  last_r1 <= 1'b0;
                  valid_r1 <= 1'b1;
                  arp_head <= 'b0;
               end
               else begin
                  arp_data_r1 <= arp_send_data;
                  data_r1 <= {arp_data_r1[15:0], arp_send_data[31:16]};
                  keep_r1 <= {arp_send_keep_r2[1:0], arp_send_keep_r1[3:2]};
                  valid_r1 <= arp_send_valid_r2 | arp_send_valid_r1;
                  last_r1 <= 1'b0;
               end
            end
            else if (!data_valid_r1 && !arp_send_valid_r)
              begin
                 if (data_symbol) begin
                    data_r1 <= {ip_data_r2[15:0], 16'h5555};
                    keep_r1 <= {data_keep_r2[1:0], 2'b00};
                    last_r1 <= data_last_r2;
                    valid_r1 <= 1'b1;
                 end
                 else if (arp_send_symbol) begin
                    data_r1 <= {arp_data_r2[15:0], 16'h5555};
                    keep_r1 <= {arp_send_keep_r2[1:0], 2'b00};
                    last_r1 <= arp_send_last_r2;
                    valid_r1 <= 1'b1;
                 end
                 data_ready <= 1'b0;
                 state <= `WAIT;
                 ri_buf_wait <= 1'b1;
                 ri_buf_translate <= 1'b1;
              end // else: !if(data_valid)
         end
         `WAIT: begin
            ri_buf_translate <= 1'b0;
            data_ready <= 1'b1;
            ri_count <= 8'h0;
            //tvalid_r <= 1'b1;
            //tkeep_r <= 4'hf;
            valid_r1 <= 1'b0;
            keep_r1 <= 1'b0;
            last_r1 <= 1'b0;
            if (tail_cnt == 2'h2) begin
               state <= `INIT;
              // tlast_r <= 1'b1;
            end
            else begin
               tail_cnt <= tail_cnt + 2'h1;
               state <= `WAIT;
            end
         end
       endcase
    end
end

endmodule
