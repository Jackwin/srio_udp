`timescale 1ns/10ps

module axis_32to8_tb ();
reg             clk_32;
reg             reset_32;
reg             clk_8;
reg [31:0]      data_gen;
reg             data_gen_tvalid;
reg [3:0]       data_gen_tkeep;
reg             data_gen_tlast;
wire            axis_tready_out;

wire [7:0]      axis_tdata_out;
wire            axis_tlast_out;
wire            axis_tvalid_out;


initial begin
    clk_32 = 1'b0;
    forever begin
        #16 clk_32 = ~clk_32;
    end
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
    data_gen = 0;
    data_gen_tvalid = 0;
    data_gen_tlast = 0;
    data_gen_tkeep = 0;
    #170;

    for (int k = 0; k < 32; k++) begin
        @(posedge clk_32);
        if (axis_tready_out) begin
            data_gen = k;
            data_gen_tvalid = 1;
            data_gen_tkeep = 'hf;
            data_gen_tlast = 0;
        end
    end
    @(posedge clk_32);
    if (axis_tready_out) begin
        data_gen = 'ha5a5a5a5;
        data_gen_tvalid = 1;
        data_gen_tkeep = 'ha;
        data_gen_tlast = 0;
    end
    for (int k = 32; k < 63; k++) begin
        @(posedge clk_32);
        if (axis_tready_out) begin
            data_gen = k;
            data_gen_tvalid = 1;
            data_gen_tkeep = 'hf;
            data_gen_tlast = 0;
        end
    end
    @(posedge clk_32);
    if (axis_tready_out) begin
        data_gen = 'ha5a5a5a5;
        data_gen_tvalid = 1;
        data_gen_tkeep = 'hd;
        data_gen_tlast = 1;
    end
    @(posedge clk_32);
    if (axis_tready_out) begin
        data_gen = 'ha5a5a5a5;
        data_gen_tvalid = 0;
        data_gen_tkeep = 0;
        data_gen_tlast = 0;
    end

    #200;
    $stop;
end
 axis32to8 axis32to8_i (
    .clk_32(clk_32),
    .reset_32(reset_32),
    .axis_tdata_in(data_gen),
    .axis_tvalid_in(data_gen_tvalid),
    .axis_tkeep_in(data_gen_tkeep),
    .axis_tlast_in(data_gen_tlast),
    .axis_tready_out(axis_tready_out),

    .clk_8(clk_8),
    .reset_8(),
    .axis_tready_in(1'b1),
    .axis_tdata_out(axis_tdata_out),
    .axis_tvalid_out(axis_tvalid_out),
    .axis_tlast_out(axis_tlast_out)
);



endmodule