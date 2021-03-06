
module my_task();
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

