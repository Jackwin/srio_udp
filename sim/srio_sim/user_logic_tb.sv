
`timescale 1ps/1ps
module user_logic_tb (
);

logic   log_clk;
logic   log_rst;
logic   nwr_ready_in;

logic [19:0] user_tsize;
logic [63:0] user_tdata;
logic [7:0] user_tkeep;
logic       user_tfirst;
logic       user_tvalid;
logic       user_tlast;

initial begin
    log_clk = 0;
    forever begin
        #5 log_clk = ~log_clk;
    end
end

initial begin
    log_rst = 1'b0;
    #45;
    log_rst = 1;
    #20;
    log_rst = 0;
end

initial begin
    nwr_ready_in = 0;
    #90;
    nwr_ready_in = 1;
    #10;
    nwr_ready_in = 0;
    #800;
    nwr_ready_in = 1;
    #10;
    nwr_ready_in = 0;
    #800;
    $stop;
end
user_logic user_logic_i
  (
    .log_clk(log_clk),
    .log_rst(log_rst),

    .nwr_ready_in(nwr_ready_in),
    .nwr_busy_in(),
    .nwr_done_in(),

    .user_tready_in(1'b1),
    .user_addr_o(),
    .user_tsize_o(user_tsize),
    .user_tdata_o(user_tdata),
    .user_tfirst_o (user_tfirst),
    .user_tvalid_o(user_tvalid),
    .user_tkeep_o(user_tkeep),
    .user_tlast_o(user_tlast)

  );

endmodule