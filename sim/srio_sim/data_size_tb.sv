`timescale 1ns/1ns

module data_size_tb (
);
`include "../rtl/my_task.v"
logic clk;
logic reset;
logic [19:0] data_gen;
logic data_valid;
logic data_last;

logic [11:0] trans_256B_times;
logic [7:0] pad_length;
logic [7:0] rounded_length;

initial begin
    clk = 0;
    forever
    #5 clk  = ~clk;
end // initial

initial  begin
    reset = 1;
    #38;
    reset = 0;
end // initial

initial begin
    data_gen = 'h0;
    data_valid = 'h0;
    data_last = 'h0;
    # 350;
    for(integer k = 1; k < 256; k++) begin
        @(posedge clk);
        data_gen = data_gen + 'h1;
    end
    @(posedge clk);
    $stop;
end

always @(posedge clk)
begin
    transDataLength(data_gen, trans_256B_times, pad_length, rounded_length);
end
/*transDataLength transDataLength_i
(
    .data_length_in(data_gen),
    .trans_256B_times(trans_256B_times),
    .pad_length(pad_length),
    .rounded_length(rounded_length)
    );
*/
task transDataLength;
        input [19:0] data_length_in; // in the size of byte, the number of bytes in the transfer minus one
        output [11:0] trans_256B_times; // times of 256B transaction
        output [7:0] pad_length; // the data added to round up to the closest boundary
        output [7:0] rounded_length;  // the closed supported value
        begin
            trans_256B_times = data_length_in[19:8];
            casex(data_length_in[7:0])
                8'b00000xxx: begin
                    pad_length = 7 - data_length_in[2:0];
                    rounded_length = 8'd8;
                end // 20'b00000000000000000xxx:
                8'b00001xxx: begin
                    pad_length = 15 - data_length_in[3:0];
                    rounded_length = 8'd16;
                end // 20'b00000000000000001xxx:
                8'b0001xxxx: begin
                    pad_length = 31 - data_length_in[4:0];
                    rounded_length = 8'd32;
                end
                8'b001xxxxx: begin
                    pad_length = 63 - data_length_in[5:0];
                    rounded_length = 8'd64;
                end
                8'b01xxxxxx: begin
                    pad_length = 127 - data_length_in[6:0];
                    rounded_length = 8'd128;
                end
                8'b1xxxxxxx: begin
                    pad_length = 255 - data_length_in[7:0];
                    rounded_length = 8'd256;
                end
                default: begin
                    pad_length = 'h0;
                    rounded_length = 'h0;
                end
            endcase
        end
    endtask

endmodule