`timescale 1ns/1ns
module input_reader # (
    parameter DATA_WIDTH = 64,
    parameter DATA_LENGTH_WIDTH = 16,
    parameter RAM_ADDR_WIDTH = 10
    )
(
    input                   clk,    // Clock
    input                   reset,

    // user data stream input
    input [DATA_WIDTH-1:0]  data_in,
    input                   data_valid_in,
    input                   data_first_in,
    input [DATA_WIDTH/8-1:0] data_keep_in,
    // data_len_in is the data actual length minuses 1
    input [DATA_LENGTH_WIDTH-1:0] data_len_in,
    input                   data_last_in,
    output                  data_ready_out,
    output                  ack_o,

    // output data to NWR
    input                   output_tready_in,
    output [DATA_WIDTH-1:0] output_tdata,
    output                  output_tvalid,
    output [DATA_WIDTH/8-1:0] output_tkeep,
    output reg [7:0]         output_data_len,
    output                  output_tlast,
    output                  output_tfirst,
    // The last 8-byte of user logic data
    output                  output_done
);

reg [DATA_LENGTH_WIDTH-1:0]     data_len_r1, data_len_r2, data_len_reg;
reg                             data_valid_r1, data_valid_r2, data_valid_p;
reg [DATA_WIDTH-1:0]            data_in_r1, data_in_r2;
reg [1:0]                       data_last_r;
reg                             data_first_r1;
wire                            data_tlast, data_tvalid;
reg [DATA_WIDTH/8-1:0]          data_keep_r1, data_keep_r2;
//Count the sent packets
reg [5:0]                       pack_trans_count;
reg [7:0]                       current_pack_length;

//Counter signals

// FIFO signals
localparam MEM_DPTH = 2**RAM_ADDR_WIDTH;
reg [DATA_WIDTH+4+8-1:0]        mem[MEM_DPTH-1:0];
reg [DATA_WIDTH+4+8-1:0]        rd_data_reg, rd_data;
wire [DATA_WIDTH+4+8-1:0]       wr_data;
reg [RAM_ADDR_WIDTH:0]          wr_ptr_reg, wr_ptr_next, rd_ptr_reg, rd_ptr_next;
reg                             rd_data_valid_next, rd_data_valid_reg;

wire full = ((wr_ptr_reg[RAM_ADDR_WIDTH] != rd_ptr_reg[RAM_ADDR_WIDTH])
            && (wr_ptr_reg[RAM_ADDR_WIDTH-1:0] == rd_ptr_reg[RAM_ADDR_WIDTH-1:0]));
wire empty = (wr_ptr_reg == rd_ptr_reg);
reg                             write;
// The last written packet
wire                            wr_tail;
wire                            wr_tail_tlast;
reg                             read;
reg                             rd_data_valid;


// Data length signals. 256-byte data is called as PACKET
reg [DATA_LENGTH_WIDTH-3-1:0]   counter;
wire                            counter_ena, counter_reset;
wire                            wr_pack_tfirst;
reg                             wr_pack_tlast;
wire                            rd_data_tfirst, rd_data_tlast, rd_pack_tfirst, rd_pack_tlast;
reg                             rd_pack_valid;
wire [DATA_WIDTH/8-1:0]         rd_pack_tkeep;
reg [DATA_LENGTH_WIDTH-1-8:0]   trans_256B_times_reg, trans_256B_times;
reg [3:0]                       pad_length_reg, pad_length;
reg [7:0]                       rounded_length_reg, rounded_length;
reg [7:0]                       tail_length, tail_length_reg;
reg [DATA_LENGTH_WIDTH-1-8:0]   pack_cnt;
wire                            pack_reset;

//Output
reg                             output_strobe;

assign data_ready_out = ~full;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        {data_valid_r1, data_valid_r1} <= 2'h0;
        data_valid_p <= 1'b0;
        data_len_r1 <= 'h0;
        data_len_r2 <= 'h0;
        data_last_r <= 'h0;
        data_in_r1 <= 'h0;
        data_in_r2 <= 'h0;
        data_keep_r1 <= 'h0;
        data_keep_r2 <= 'h0;
        data_first_r1 <= 1'b0;
    end
    else begin
        data_first_r1 <= data_first_in;
        data_valid_r1 <= data_valid_in;
        data_valid_r2 <= data_valid_r1;
        data_valid_p <= data_valid_in & ~data_valid_r1;
        data_len_r1 <= data_len_in;
        data_len_r2 <= data_len_r1;
        data_last_r[1:0] <= {data_last_r[0], data_last_in};
        data_in_r1 <= data_in;
        data_in_r2 <= data_in_r1;
        data_keep_r1 <= data_keep_in;
        data_keep_r2 <= data_keep_r1;
    end
end
assign data_tlast  = data_last_r[0];
assign data_tvalid  = data_valid_r1;
//Flag of unused data writtten to RAM
// In WR_TAIL, fill ZEROs in data to meet the demand of ROUNDED_LENGTH
assign wr_tail = (counter[DATA_LENGTH_WIDTH-3-1:5] == trans_256B_times_reg
                && (counter[4:0] > tail_length_reg[7:3])) ? 1'b1 : 1'b0;

assign wr_tail_tlast = (counter[DATA_LENGTH_WIDTH-3-1:5] == trans_256B_times_reg)
                        && wr_pack_tlast;

assign wr_data = !wr_tail ? {data_in_r1, data_keep_r1, data_first_r1, data_tlast,
                wr_pack_tfirst, wr_pack_tlast}
                : {64'h0, 8'h0, 1'b0, wr_tail_tlast, 1'b0, wr_tail_tlast};
assign counter_ena = data_tvalid || wr_tail;
// Data length process
always @(posedge clk) begin
    if (reset) begin
        data_len_reg <= 'h0;
    end
    else begin
        if (data_first_in) begin
            data_len_reg <= data_len_r1;
        end
    end
end

always @* begin
    transLengthComp(data_len_in, trans_256B_times, pad_length, rounded_length, tail_length);
end

// TODO: delay one clock cycle for data_first, data_tlast to align with current_pack_length
//TODO: 1 Seperate output_valid ?
 //       2 interface with db_req
 //       3 db_req NWR deals with the input_length
//------------------------------Count the output packet---------------------------
always @(posedge clk) begin
    if (reset) begin
        pack_trans_count <= 'h0;
    end
    else begin
        // Latch the transmission times of 256-byte packet
        if (data_first_in) begin
            pack_trans_count <= trans_256B_times;
        end
        else if (output_tlast) begin
            pack_trans_count <= pack_trans_count - 'h1;
        end
        else if (output_done) begin
            pack_trans_count <= 'h0;
        end
        else begin
            pack_trans_count <= pack_trans_count;
        end
    end
end

always @* begin
    if (pack_trans_count == 'h0) begin
        // Data-sent length is the actual length minuses 1 in byte
        current_pack_length = rounded_length - 'h1;
    end
    else if (&pack_trans_count == 1'b1) begin
        current_pack_length = 'h0;
    end
    else begin
        current_pack_length = 'hff;
    end
end

always @ (posedge clk) begin
    if (reset) begin
        output_data_len <= 'h0;
    end
    else if (data_first_in) begin
        output_data_len <= current_pack_length;
    end
end

//assign output_data_len = current_pack_length;
//--------------------------------------------------------------------------------

always @(posedge clk) begin
    if (reset) begin
        trans_256B_times_reg <= 'hff;
        pad_length_reg <= 'h0;
        rounded_length_reg <= 'h0;
        tail_length_reg <= 'h0;
    end
    else begin
        if (data_first_in) begin
            trans_256B_times_reg <= trans_256B_times;
            pad_length_reg <= pad_length;
            tail_length_reg <= tail_length;
            rounded_length_reg <= rounded_length;
           // trans_tail_length_reg <= data_len_r1[7:0];
        end
    end
end

// 256-byte Package
assign counter_reset = wr_tail_tlast;
always @(posedge clk) begin
    if (reset) begin
        counter <= 'h0;
    end
    else begin
        if (counter_reset) begin
            counter <= 'h0;
        end
        else if (counter_ena) begin
            counter <= counter + 'h1;
        end
    end
end

assign wr_pack_tfirst = (counter_ena == 1'b1 && counter[4:0] == 'h0) ? 1'b1 : 1'b0;
//assign wr_pack_tlast = (counter_ena == 1'b1 && counter[4:0] == 'h1f || wr_tail_tlast)
//                        ? 1'b1 : 1'b0;
reg [4:0] tmp;
always @* begin
    wr_pack_tlast = 1'b0;
    if (counter_ena) begin
        if (counter[DATA_LENGTH_WIDTH-3-1:5] == trans_256B_times_reg) begin
            tmp = rounded_length_reg[7:3] - 'h1;
            wr_pack_tlast = (counter[4:0] == tmp);
        end
        else begin
            wr_pack_tlast = (counter[4:0] == 'h1f); // 256-byte
        end
    end
    else begin
        wr_pack_tlast = 1'b0;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        pack_cnt <= 'h0;
    end
    else begin
        if (rd_data_tlast) begin
            pack_cnt <= 'h0;
        end
        else if (rd_pack_tlast) begin
            pack_cnt <= pack_cnt + 'h1;
        end
    end
end


/*
always @* begin
    if (pack_cnt != trans_256B_times_reg) begin
        output_tkeep = {(DATA_WIDTH/8){1'b1}};
    end
    else begin
        if (rd_pack_valid) begin
            output_tkeep = rd_pack_tkeep;
        end
        else begin
            output_tkeep = {(DATA_WIDTH/8){1'b0}};
        end
    end
end


always @* begin
    if (pack_cnt != trans_256B_times_reg && rd_pack_tfirst) begin
        output_tkeep = 'hff;
    end
    else if (pack_cnt == trans_256B_times_reg && rd_pack_tfirst) begin
        output_tkeep = rounded_length;
    end
end
*/
// Write FIFO
always @* begin
    write = 1'b0;
    wr_ptr_next = wr_ptr_reg;
    if ((data_tvalid && ~full) || wr_tail ) begin
        write = 1'b1;
        wr_ptr_next = wr_ptr_reg + 'h1;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset) begin
        wr_ptr_reg  <= 0;
    end
    else begin
        wr_ptr_reg  <= wr_ptr_next;
       if (write) begin
                mem[wr_ptr_reg[RAM_ADDR_WIDTH-1:0]] <= wr_data;
         end
    end
end

// Read FIFO

//assign read = output_tready_in && fetch_data_in && ~empty ;
always @(posedge clk ) begin
    if (reset) begin
        rd_pack_valid <= 1'b0;
    end
    else begin
        if (rd_pack_tfirst) begin
            rd_pack_valid <= 1'b1;
        end
        else if (rd_pack_tlast) begin
            rd_pack_valid <= 1'b0;
        end
        else begin
            rd_pack_valid <= rd_pack_valid;
        end
    end
end

always @* begin
    rd_ptr_next = rd_ptr_reg;
    read = 1'b0;
    rd_data_valid_next = rd_data_valid_reg;

    //if (fetch_data_in && (output_tready_in | ~rd_data_valid_reg)) begin
    if (output_tready_in | ~rd_data_valid_reg) begin
        if (~empty) begin
            read = 1'b1;
            rd_ptr_next = rd_ptr_reg + 'h1;
            rd_data_valid_next = 1'b1;
        end
        else begin
            rd_data_valid_next = 1'b0;
        end
    end
end

reg [7:0] rd_data_cnt;

always @(posedge clk) begin
    if (reset) begin
        rd_data_cnt <= 'h0;
    end
    else begin
        if (rd_data_tlast) begin
            rd_data_cnt <= 'h0;
        end
        else if (read) begin
            rd_data_cnt <= rd_data_cnt + 'h1;
        end
    end
end

always @(posedge clk) begin
    if (reset) begin
        rd_ptr_reg  <= 'h0;
        rd_data_valid_reg <= 1'b0;
        rd_data <= 'h0;
    end
    else begin
        rd_ptr_reg <= rd_ptr_next;
        rd_data_valid_reg <= rd_data_valid_next;
        if (read) begin
            rd_data <= mem[rd_ptr_reg[RAM_ADDR_WIDTH-1:0]];
        end
    end
end

assign rd_data_tfirst = rd_data[3];
assign rd_data_tlast = rd_data[2];
assign rd_pack_tfirst  = rd_data[1];
assign rd_pack_tlast = rd_data[0];
assign rd_pack_tkeep = rd_data[11:4];

//output
assign output_tdata = rd_data[DATA_WIDTH+4+8-1:4+8];
assign output_tkeep = rd_pack_tkeep;
//assign output_tlast = rd_pack_tlast && rd_data_tlast && rd_data_valid_reg;
assign output_tlast = rd_pack_tlast && rd_data_valid_reg;
assign output_tvalid = rd_data_valid_reg;
assign output_tfirst = rd_pack_tfirst;

// Acknowledge to the use_logic master
assign ack_o = rd_pack_tlast && rd_data_tlast && rd_data_valid_reg;
// Tell db_req the current transmission is done
assign output_done = rd_pack_tlast && rd_data_tlast && rd_data_valid_reg;


task transLengthComp;
    input [19:0] data_length_in; // in the size of byte, the number of bytes in the transfer minus one
    output [11:0] trans_256B_times; // times of 256B transaction
    output [3:0] pad_length; // the data added to round up to the closest boundary
    output [7:0] rounded_length;  // the closest supported value
    output [7:0] tail_length;
    begin
        trans_256B_times = data_length_in[19:8];
        // not a whole 256-byte packet
        tail_length = data_length_in[7:0];
        casex(data_length_in[7:0])
            8'b00000xxx: begin
                //pad_length = 7 - data_length_in[2:0];
                // The unite is 8-byte
                pad_length = 'h1;
                rounded_length = 8'd16;
            end // 20'b00000000000000000xxx:
            8'b00001xxx: begin
               // pad_length = 15 - data_length_in[3:0];
                pad_length = 'h0;
                rounded_length = 8'd16;
            end // 20'b00000000000000001xxx:
            8'b0001xxxx: begin
               // pad_length = 31 - data_length_in[4:0];
               pad_length = 4'b0001 - data_length_in[3];
                rounded_length = 8'd32;
            end
            8'b001xxxxx: begin
                //pad_length = 63 - data_length_in[5:0];
                pad_length = 4'b0011- data_length_in[4:3];
                rounded_length = 8'd64;
            end
            8'b01xxxxxx: begin
                //pad_length = 127 - data_length_in[6:0];
                pad_length = 4'b0111 - data_length_in[5:3];
                rounded_length = 8'd128;
            end
            8'b1xxxxxxx: begin
                //pad_length = 255 - data_length_in[7:0];
                pad_length = 4'b1111 - data_length_in[6:3];
                rounded_length = 8'd0; //256
            end
            default: begin
                pad_length = 'h0;
                rounded_length = 'h0;
            end
        endcase
    end
endtask



endmodule