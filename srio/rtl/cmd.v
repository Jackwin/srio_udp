`timescale 1ns/1ns
`define SELF_CHECK_REQ 8'h21
`define DSP_READY 8'h25
`define DSP_NOT_READY 8'h2a
module cmd
(
    input           clk,
    input           reset,
    input[7:0]      cmd_axis_tdata_in,
    input           cmd_axis_tvalid_in,
    input           cmd_axis_tlast_in

    // Commands sent to RapidIO
    output          cmd2rapidio_self_check,

    output [7:0]    cmd2rapidio_tdata_out,
    output          cmd2rapidio_axis_tvalid_out,
    output          cmd2rapidio_axis_tlast_out,

    input           dsp_ready_in,

    // Feedback to CPU
    output [7:0]    cmd2cpu_tdata_out,
    output          cmd2cpu_tvalid_out,
    output          cmd2cpu_tlast_out
);

reg                 self_check;
reg [7:0]           cmd2cpu_tdata;
reg                 cmd2cpu_tvalid;
reg                 cmd2cpu_tlast;
reg [9:0]           timer_cnt;

assign cmd2rapidio_self_check = self_check;
assign cmd2cpu_tdata_out = cmd2cpu_tdata;
assign cmd2cpu_tvalid = cmd2cpu_tvalid;
assign cmd2cpu_tlast = cmd2cpu_tlast;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        self_check <= 1'b0;
    end
    else begin
        if (cmd_axis_tdata_in == `SELF_CHECK_REQ && cmd_axis_tvalid_in) begin
            self_check <= 1'b1;
        end
        else begin
            self_check <= 1'b0;
        end
    end
end

// Feedback the rapidIO state to CPU
always @(posedge clk or posedge reset) begin
    if (reset) begin
        cmd2cpu_tdata <= 'h0;
        cmd2cpu_tvalid <= 1'b0;
        cmd2cpu_tlast <= 1'b0;
    end
    else begin
        if (dsp_ready_in) begin
            cmd2cpu_tdata <= `DSP_READY;
            cmd2cpu_tvalid <= 1'b1;
            cmd2cpu_tlast <= 1'b1;
        end
        else if (timer_out) begin
            cmd2cpu_tdata <= `DSP_NOT_READY;
            cmd2cpu_tvalid <= 1'b1;
            cmd2cpu_tlast <= 1'b1;
        end
        else begin
            cmd2cpu_tdata <= 'h0;
            cmd2cpu_tvalid <= 1'b0;
            cmd2cpu_tlast <= 1'b0;
        end // else
    end
end

alwasy @(posedge clk or posedge reset) begin
    if (reset) begin
        timer_ena <= 1'b0;
    end
    else begin
        if (self_check) begin
            timer_ena <= 1'b1;
        end
        else if (timer_out || dsp_ready_in) begin
            timer_ena <= 1'b0;
        end
    end
end


timer #
(   .TIMER_WIDTH(10))
timer_self_check
(
    .clk      (clk),
    .reset    (reset),
    .enable   (enable),
    .timer_out(timer_out)
);



endmodule // cmd