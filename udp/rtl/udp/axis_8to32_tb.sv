`timescale 1ns/1ps

module axis_8to32_tb ();
reg             clk_32;
reg             reset_32;
reg             clk_8;
reg             reset_8;
reg [7:0]      data_gen;
reg             data_gen_tvalid;
reg [3:0]       data_gen_tkeep;
reg             data_gen_tlast;
wire            axis_tready_out;

wire [32:0]     axis_tdata_out;
wire [3:0]      axis_tkeep_out;
wire            axis_tlast_out;
wire            axis_tvalid_out;


initial begin
    clk_32 = 1'b0;
    forever begin
        #16 clk_32 = ~clk_32;
    end
end

initial begin
    reset_8 = 1;
    #50;
    reset_8 = 0;
end

initial begin
    reset_32 = 1;
    #100;
    reset_32 = 0;
end

initial begin
    clk_8 = 1'b0;
    forever begin
        #4 clk_8 = ~clk_8;
    end
end

initial begin
    data_gen <= 0;
    data_gen_tvalid <= 0;
    data_gen_tlast <= 0;
    #170;

    for (int k = 0; k < 32; k++) begin
        @(posedge clk_8);
        if (axis_tready_out) begin
            data_gen <= k;
            data_gen_tvalid <= 1;
            data_gen_tlast <= 0;
        end
    end
    @(posedge clk_8);
    if (axis_tready_out) begin
        data_gen <= 'ha5;
        data_gen_tvalid <= 0;
        data_gen_tlast <= 0;
    end

    @(posedge clk_8);
     if (axis_tready_out) begin
        data_gen <= 'ha3;
        data_gen_tvalid <= 0;
        data_gen_tlast <= 0;
    end
    for (int k = 32; k < 63; k++) begin
        @(posedge clk_8);
        if (axis_tready_out) begin
            data_gen <= k;
            data_gen_tvalid <= 1;
            data_gen_tlast <= 0;
        end
    end

    @(posedge clk_8);
    if (axis_tready_out) begin
        data_gen <= 'ha3;
        data_gen_tvalid <= 0;
        data_gen_tlast <= 0;
    end
    @(posedge clk_8);
    if (axis_tready_out) begin
        data_gen <= 'ha2;
        data_gen_tvalid <= 1;
        data_gen_tlast <= 0;
    end
    @(posedge clk_8);
    if (axis_tready_out) begin
        data_gen <= 'ha5;
        data_gen_tvalid <= 1;
        data_gen_tlast <= 1;
    end
    @(posedge clk_8);
    if (axis_tready_out) begin
        data_gen <= 'ha5;
        data_gen_tvalid <= 0;
        data_gen_tlast <= 0;
    end

    #2000;
    $stop;
end
 axis_8to32 axis8to32_i (
    .clk_8(clk_8),
    .reset_8(reset_8),
    .axis_tdata_in(data_gen),
    .axis_tvalid_in(data_gen_tvalid),
    .axis_tlast_in(data_gen_tlast),
    .axis_tready_out(axis_tready_out),

    .clk_32(clk_32),
    .reset_32(reset_32),
    .axis_tready_in(1'b1),
    .axis_tdata_out(axis_tdata_out),
    .axis_tvalid_out(axis_tvalid_out),
    .axis_tkeep_out (axis_tkeep_out),
    .axis_tlast_out(axis_tlast_out)
);



endmodule