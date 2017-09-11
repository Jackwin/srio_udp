`timescale 1ns/1ps

module timer # (
parameter   TIMER_WIDTH = 10
)
(
    input           clk,
    input           reset,
    input           enable,

    output  reg     timer_out

);

reg [TIMER_WIDTH-1:0]   timer_cnt;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        timer_cnt <= 'h0;
        timer_out <= 1'b0;
    end
    else begin
        timer_out <= 1'b0;
        if (timer_cnt == {TIMER_WIDTH{1'b1}}) begin
            timer_out <= 1'b1;
            timer_cnt <= 'h0;
        end
        else begin
            timer_cnt <= timer_cnt + 'h1;
        end
    end
end


endmodule