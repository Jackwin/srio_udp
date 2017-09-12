`timescale 1ns/1ns
module input_reader_tb();

localparam DATA_WIDTH = 64;
localparam DATA_LENGTH_WIDTH = 20;
localparam RAM_ADDR_WIDTH = 10;
logic log_clk;
logic log_rst;
logic [DATA_WIDTH-1:0] data_gen;
logic  data_gen_valid;
logic [DATA_WIDTH/8-1:0] data_gen_tkeep;
logic [DATA_LENGTH_WIDTH-1:0] data_gen_len;
logic data_gen_tlast;
logic data_gen_tfirst;
logic data_ready_out;
logic fetch_data_in;
logic output_tready;
logic [DATA_WIDTH-1:0] output_tdata;
logic output_tvalid;
logic [DATA_WIDTH/8-1:0] output_tkeep;
logic output_tlast;
logic output_tfisrt;
logic output_done;
logic ack;
localparam DATA_NUM = 32;
initial begin
    log_clk = 0;
forever
    #5 log_clk  = ~log_clk;
end // initial

initial  begin
    log_rst = 1;
    #38;
    log_rst = 0;
end // initial

initial begin
    data_gen = 'h0;
    data_gen_valid = 'h0;
    data_gen_tlast = 'h0;
    data_gen_tkeep = 'h0;
    data_gen_tfirst = 'h0;
    data_gen_len = 'h0;
    # 350;
    @ (posedge log_clk)
    data_gen_tfirst = 1;
    data_gen = 'hff;
    data_gen_tkeep = 8'hf0;
    data_gen_valid = 1;
    data_gen_len = (DATA_NUM + 1) * 8 - 1;
    for(integer k = 0; k < DATA_NUM; k++) begin
        @(posedge log_clk);
        data_gen_tfirst = 0;
        data_gen_valid = 1'b1;
        data_gen = data_gen + 'h1;
        data_gen_tkeep = 'hff;
    end
    data_gen_tfirst = 0;
    data_gen_tlast = 'h1;
    data_gen_tkeep = 'hff;
    @(posedge log_clk);
    data_gen_valid = 'h0;
    data_gen_tlast = 'h0;
    data_gen_tkeep = 'h0;
    #300;
    $stop;

end

initial begin
    fetch_data_in = 0;
    #550;
    @(posedge log_clk) fetch_data_in = 1;
end

initial begin
    output_tready = 1;
    #600;
    @(posedge log_clk);
    output_tready = 0;
    @(posedge log_clk)
    output_tready = 1;
    for(int k = 0; k < 5; k++) begin
        @(posedge log_clk);
        output_tready = 1;
    end
    @(posedge log_clk);
    output_tready = 0;
    @(posedge log_clk)
    output_tready = 1;
    for(int k = 0; k < 3; k++) begin
        @(posedge log_clk);
        output_tready = 1;
    end
    @(posedge log_clk);
    output_tready = 0;
    @(posedge log_clk)
    output_tready = 1;
    for(int k = 0; k < 8; k++) begin
        @(posedge log_clk);
        output_tready = 1;
    end
end



 input_reader # (
    .DATA_WIDTH(DATA_WIDTH),
    .DATA_LENGTH_WIDTH(DATA_LENGTH_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    )
input_reader_i (
    .clk(log_clk),    // Clock
    .reset(log_rst),

    .data_in(data_gen),
    .data_valid_in(data_gen_valid),
    .data_first_in(data_gen_tfirst),
    .data_keep_in(data_gen_tkeep),
    .data_len_in(data_gen_len),
    .data_last_in(data_gen_tlast),
    .data_ready_out(),
    .ack_o(ack),

    .fetch_data_in(fetch_data_in),
    .output_tready(output_tready),
    .output_tdata(output_tdata),
    .output_tvalid(output_tvalid),
    .output_tkeep(output_tkeep),
    .output_tlast(output_tlast),
    .output_tfisrt(output_tfisrt),
    .output_done (output_pack_tlast)
);

endmodule // input_reader
