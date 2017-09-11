`timescale 1ps/1ps
`define INIT 2'h0 //all
`define RECV 2'h1 //ri, ra
`define MAC  2'h1 //trans
`define IP   2'h1 //cpu
`define WAIT 2'h2 //ri, ra, trans
`define ARP  2'h2
`define REQ  2'h3 //trans


module send_buffer
#(
    parameter SRC_MAC = 48'h55ffeeddccbb,
    parameter DES_MAC = 48'hdd0504030201
    )
(

    input               clk,
    input               reset,
    //ip send
    input [31:0]        ip_send_addr,
    input [31:0]        ip_send_data,
    input               ip_send_valid,
    input [3:0]         ip_send_keep,
    input               ip_send_last,
    output reg          ip_send_ready,
    //arp_send
    //**send reply ports
    input [47:0]        arp_send_mac_addr,
    input [31:0]        arp_send_data,
    input               arp_send_valid,
    input [3:0]         arp_send_keep,
    input               arp_send_last,
    output reg          arp_send_ready,
    //**send request ports
    input               req_ready,
    output reg [31:0]   arp_send_ip_addr,
    output reg          req_en,
    //mac_cache
    input [47:0]        r_mac_addr,
    output reg          r_mac_cache_en,
    output reg [31:0]   r_mac_cache_ip_addr,

    output reg [31:0]   axis_tdata_out,
    output reg          axis_tvalid_out,
    output reg [3:0]    axis_tkeep_out,
    output reg          axis_tlast_out,
    input               axis_tready_in
);


reg [1:0]           tail_cnt;


//arp vars
reg [1:0]           ra_state;
reg                 arp_head;
reg                 arp_send_symbol;
reg                 arp_send_valid_r;
reg                 cpu_arp_done;

reg [47:0]          ra_mac_addr;
reg [31:0]          ra_data[6:0];
reg [2:0]           ra_count;
//ip vars
reg [31:0]          data_r1, data_r2, data_r3 ='h0;
reg [3:0]           keep_r1, keep_r2, keep_r3;
reg                 last_r1, last_r2, last_r3;
reg                 valid_r1, valid_r2, valid_r3;
reg [3:0]           ip_send_keep_r1, ip_send_keep_r2;
reg                 ip_send_last_r1, ip_send_last_r2;
reg                 ip_send_valid_r1, ip_send_valid_r2;
reg [31:0]          arp_data_r1, arp_data_r2, arp_data_r3, arp_data_r4, arp_data_r5;
reg [3:0]           arp_send_keep_r1, arp_send_keep_r2, arp_send_keep_r3, arp_send_keep_r4, arp_send_keep_r5;
reg                 arp_send_last_r1, arp_send_last_r2;
reg                 arp_send_valid_r1, arp_send_valid_r2;

reg [31:0]          ip_data_r1, ip_data_r2;
reg                 ip_send_valid_r;
reg                 ip_head;
reg [1:0]           buffer_cnt;
reg                 ip_send_symbol;

reg [1:0]           ri_state;
reg [47:0]          ri_mac_addr;
reg [31:0]          ri_ip_addr;
reg [31:0]          ri_data[255:0];
reg [7:0]           ri_count;
reg                 ri_buf_wait; //goes high after recving ip data, low after sent to cpu
reg                 ri_buf_translate; //goes high after recving ip data
//translation vars
reg [1:0]               mac_state;
reg [15:0]               mac_timeout;

integer               i;

//receive arp reply state machine
always @(posedge clk or posedge reset) begin
  if(reset) begin
     ra_state <= `INIT;
     ra_count <= 3'h0;
    // arp_send_ready <= 1'b1;
     ra_mac_addr <= 48'h0;
     for(i = 3'h0; i < 3'h7; i = i+1)
       ra_data[i] <= 32'h0;
  end else

    begin
       case (ra_state)
         `INIT: begin
            if (arp_send_valid) begin
               ra_state <= `RECV;
               ra_mac_addr <= arp_send_mac_addr;
               ra_data[0] <= arp_send_data;
               ra_count <= 3'h1; //start receiving at the second word
            end
         end
         `RECV: begin
            if (ra_count < 3'h7) begin
               ra_data[ra_count] <= arp_send_data;
               ra_count <= ra_count + 3'h1;
            end else
              begin
                 ra_count <= 3'h0;
                // arp_send_ready <= 1'b0;
                 ra_state <= `WAIT;
              end
         end
         `WAIT: begin
            if (cpu_arp_done == 1'b1) begin
               ra_state <= `INIT;
               //arp_send_ready <= 1'b1;
            end
         end
       endcase
    end
end

//receive ip state machine
always @(posedge clk or posedge reset) begin
  if(reset) begin
     ri_state <= `INIT;
     ri_count <= 8'h0;
     ri_buf_wait <= 1'b0;
     ip_send_ready <= 1'b1;
     arp_send_ready <= 1'b1;
     ri_buf_translate <= 1'b0;
     ip_head <= 'b1;
     arp_head <= 'b1;
     ip_send_symbol <= 'b0;
     arp_send_symbol <= 'b0;
     buffer_cnt <= 'h0;
     tail_cnt <= 'h0;
     arp_send_valid_r <= 1'b0;
     {ip_send_keep_r2, ip_send_keep_r1} <= 'h0;
     {ip_send_last_r2, ip_send_last_r1} <= 'h0;
     {ip_send_valid_r2, ip_send_valid_r1} <= 'h0;
     {arp_send_keep_r2, arp_send_keep_r1} <= 'h0;
     {arp_send_last_r2, arp_send_last_r1} <= 'h0;
     {arp_send_valid_r2, arp_send_valid_r1} <= 'h0;
     {arp_data_r1, arp_data_r2, arp_data_r3, arp_data_r4, arp_data_r5} <= 'h0;
     {keep_r3, keep_r2, keep_r1} <= 'h0;
     {last_r3, last_r2, last_r1} <= 'h0;
     for(i = 8'h0; i < 8'hFF; i = i+1)
       ri_data[i] <= 32'h0;
  end else
    begin
       axis_tdata_out <= data_r3;
       data_r3 <= data_r2;
       data_r2 <= data_r1;

       axis_tkeep_out <= keep_r3;
       keep_r3 <= keep_r2;
       keep_r2 <= keep_r1;

       axis_tvalid_out <= valid_r3;
       valid_r3 <= valid_r2;
       valid_r2 <= valid_r1;

       axis_tlast_out <= last_r3;
       last_r3 <= last_r2;
       last_r2 <= last_r1;

       ip_data_r1 <= ip_send_data;
       ip_data_r2 <= ip_data_r1;

       ip_send_valid_r1 <= ip_send_valid;
       ip_send_valid_r2 <= ip_send_valid_r1;

       ip_send_keep_r1 <= ip_send_keep;
       ip_send_keep_r2 <= ip_send_keep_r1;

       ip_send_last_r1 <= ip_send_last;
       ip_send_last_r2 <= ip_send_last_r1;

       arp_data_r1 <= arp_send_data;
       arp_data_r2 <= arp_data_r1;
       arp_data_r3 <= arp_data_r2;


       arp_send_valid_r1 <= arp_send_valid;
       arp_send_valid_r2 <= arp_send_valid_r1;

       arp_send_keep_r1 <= arp_send_keep;
       arp_send_keep_r2 <= arp_send_keep_r1;

       arp_send_last_r1 <= arp_send_last;
       arp_send_last_r2 <= arp_send_last_r1;

       arp_send_valid_r <= arp_send_valid;

       case (ri_state)
         `INIT: begin
            tail_cnt <= 'h0;
            if (ip_send_valid & axis_tready_in) begin
               data_r3 <= DES_MAC[47:16];
               data_r2 <= {DES_MAC[15:0], SRC_MAC[47:32]};
               data_r1 <= SRC_MAC[31:0];
               keep_r3 <= 'hf;
               keep_r2 <= 'hf;
               keep_r1 <= 'hf;
               last_r3 <= 1'b0;
               last_r2 <= 1'b0;
               last_r1 <= 1'b0;
               {valid_r3, valid_r2, valid_r1} <= 3'b111;

               // ip_data_r1 <= ip_send_data;
               ip_head <= 1'b1;
               ri_state <= `RECV;
               ri_ip_addr <= ip_send_addr;
               ri_count <= 8'h1; //start receiving at the second word
            end // if (ip_send_valid)
            else if (arp_send_valid & axis_tready_in) begin
               data_r3 <= DES_MAC[47:16];
               data_r2 <= {DES_MAC[15:0], SRC_MAC[47:32]};
               data_r1 <= SRC_MAC[31:0];
               keep_r3 <= 'hf;
               keep_r2 <= 'hf;
               keep_r1 <= 'hf;
               last_r3 <= 1'b0;
               last_r2 <= 1'b0;
               last_r1 <= 1'b0;
               {valid_r3, valid_r2, valid_r1} <= 3'b111;
               //arp_data_r1 <= arp_send_data;
               arp_head <= 1'b1;
               ri_state <= `RECV;
            end
            else begin
               ri_state <= `INIT;

            end // else: !if(arp_send_valid)
         end
         `RECV: begin
            if (ip_send_valid_r1 && !arp_send_valid_r && axis_tready_in) begin
                ip_send_symbol <= 'b1;
                arp_send_symbol <= 1'b0;

                arp_send_ready <= 1'b0;
                ip_send_ready <= 1'b1;
                if (ip_head) begin
                    data_r1 <= {16'h0800, ip_data_r1[31:16]};
                    keep_r1 <= {2'b11, ip_send_keep_r1[3:2]};
                    last_r1 <= 1'b0;
                    valid_r1 <= 1'b1;
                    ip_head <= 1'b0;
                end
                else begin
                    data_r1 <= {ip_data_r2[15:0], ip_data_r1[31:16]};
                    keep_r1 <= {ip_send_keep_r2[1:0], ip_send_keep_r1[3:2]};
                    last_r1 <= 1'b0;
                    valid_r1 <= ip_send_valid_r2 | ip_send_valid_r1;
                    buffer_cnt <= 'h1;
                end
                    ri_data[ri_count] <= ip_send_data;
                    ri_count <= ri_count + 8'h1;
            end
            else if (!ip_send_valid_r1 && arp_send_valid_r && axis_tready_in) begin
                arp_send_symbol <= 1'b1;
                ip_send_symbol <= 1'b0;
                ip_send_ready <= 1'b0;
                arp_send_ready <= 1'b1;
                if (arp_head) begin
                    data_r1 <= {16'h0806, arp_data_r1[31:16]};
                    keep_r1 <= {2'b11, arp_send_keep_r1[3:2]};
                    last_r1 <= 1'b0;
                    valid_r1 <= 1'b1;
                    arp_head <= 'b0;
                end
                else begin
                    data_r1 <= {arp_data_r2[15:0], arp_data_r1[31:16]};
                    keep_r1 <= {arp_send_keep_r2[1:0], arp_send_keep_r1[3:2]};
                    valid_r1 <= arp_send_valid_r2 | arp_send_valid_r1;
                    last_r1 <= 1'b0;
                end
            end
            else if (!ip_send_valid_r1 && !arp_send_valid_r && axis_tready_in)begin
                if (ip_send_symbol) begin
                    data_r1 <= {ip_data_r2[15:0], 16'h5555};
                    keep_r1 <= {ip_send_keep_r2[1:0], 2'b00};
                    last_r1 <= ip_send_last_r2;
                    valid_r1 <= 1'b1;
                end
                else if (arp_send_symbol) begin
                    data_r1 <= {arp_data_r2[15:0], 16'h5555};
                    keep_r1 <= {arp_send_keep_r2[1:0], 2'b00};
                    last_r1 <= arp_send_last_r2;
                    valid_r1 <= 1'b1;
                end
                ip_send_ready <= 1'b0;
                arp_send_ready <= 1'b0;
                ri_state <= `WAIT;
                ri_buf_wait <= 1'b1;
                ri_buf_translate <= 1'b1;
            end // else: !if(ip_send_valid)
            else begin
                ip_send_ready <= 1'b0;
                 arp_send_ready <= 1'b0;
                ri_state <= `WAIT;
            end
        end
         `WAIT: begin
            ri_buf_translate <= 1'b0;
            ip_send_ready <= 1'b1;
            arp_send_ready <= 1'b1;
            ri_count <= 8'h0;
            //axis_axis_tvalid_out_out_r <= 1'b1;
            //tkeep_r <= 4'hf;
            valid_r1 <= 1'b0;
            keep_r1 <= 1'b0;
            last_r1 <= 1'b0;
            ip_send_symbol <= 1'b0;
            arp_send_symbol <= 1'b0;
            if (tail_cnt == 2'h2) begin
               ri_state <= `INIT;
              // axis_tlast_out_r <= 1'b1;
            end
            else begin
               tail_cnt <= tail_cnt + 2'h1;
               ri_state <= `WAIT;
            end
         end
       endcase
    end
end

//ip->mac translation state machine
always @(posedge clk) begin
  if(reset) begin
     mac_state <= `INIT;
     mac_timeout <= 16'hFFFF;
     ri_mac_addr <= 48'h0;
     r_mac_cache_en <= 1'b0;
     r_mac_cache_ip_addr <= 32'h0;
     req_en <= 1'b0;
     arp_send_ip_addr <= 32'b0;
  end else
    begin
       case (mac_state)
         `INIT: begin
            if (ri_buf_translate) begin
               mac_state <= `MAC;
               r_mac_cache_en <= 1'b1;
               r_mac_cache_ip_addr <= ri_ip_addr;
            end
         end
         `MAC: begin
            r_mac_cache_en <= 1'b0;
            if (r_mac_addr == 48'h0) begin
               //no translation, need to send an arp request
               $display("arp request time!");
               mac_state <= `REQ;
            end else
              begin
                 //found a translation, use it and done
                 $display("found translation in mac cache!");
                 ri_mac_addr <= r_mac_addr;
                 mac_state <= `INIT;
              end
         end
         `REQ: begin
            if(req_ready) begin
               arp_send_ip_addr <= ri_ip_addr;
               req_en <= 1'b1;
               mac_state <= `WAIT;
            end
         end
         `WAIT: begin
            mac_timeout <= mac_timeout - 16'h1;
            if (mac_timeout == 16'hFFFF) begin
               $display("waiting for reply!");
               //turn off arp request
               req_en <= 1'b0;
               //turn mac cache back on
               r_mac_cache_en <= 1'b1;
               r_mac_cache_ip_addr <= ri_ip_addr;
            end else
              if (r_mac_addr != 48'h0) begin
                 $display("got translation!");
                 //found a translation, use it and done
                 r_mac_cache_en <= 1'b0;
                 ri_mac_addr <= r_mac_addr;
                 mac_state <= `INIT;
              end else
                if (mac_timeout == 16'h0) begin
                   $display("timeout!");
                   //waited long enough, error out
                   r_mac_cache_en <= 1'b0;
                   ri_buf_wait <= 1'b0;
                   mac_state <= `INIT;
                end
         end
       endcase
    end
end

endmodule
