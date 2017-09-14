`timescale 1ns/1ns

module db_resp
#(parameter SIM = 1)
(
    input               log_clk,
    input               log_rst,

    input wire [15:0]   src_id,
    input wire [15:0]   des_id,

    input wire [1:0]    ed_ready_in,

    input wire          treq_tvalid_in,
    output wire         treq_tready_o,
    input wire          treq_tlast_in,
    input wire [63:0]   treq_tdata_in,
    input wire [7:0]    treq_tkeep_in,
    input wire [31:0]   treq_tuser_in,

    // response interface
    input wire          tresp_tready_in,
    output reg          tresp_tvalid_o,
    output reg          tresp_tlast_o,
    output reg [63:0]   tresp_tdata_o,
    output reg [7:0]    tresp_tkeep_o,
    output reg [31:0]   tresp_tuser_o
        );
// Local parameter
localparam [3:0] NREAD  = 4'h2;
localparam [3:0] NWRITE = 4'h5;
localparam [3:0] SWRITE = 4'h6;
localparam [3:0] DOORB  = 4'hA;
localparam [3:0] MESSG  = 4'hB;
localparam [3:0] RESP   = 4'hD;

localparam [3:0] TNWR   = 4'h4;
localparam [3:0] TNWR_R = 4'h5;
localparam [3:0] TNRD   = 4'h4;

localparam [3:0] TNDATA = 4'h0;
localparam [3:0] MSGRSP = 4'h1;
localparam [3:0] TWDATA = 4'h8;


localparam [64*2-1:0] db_instr = {
// srcTID  FTYPE  R    R      prio  CRF    R     Info      R
        {8'h00, DOORB, 4'b0, 1'b0, 2'h1, 1'b0, 12'b0, 16'h0100, 16'h0},   //endpoint is ready
        {8'h00, DOORB, 4'b0, 1'b0, 2'h1, 1'b0, 12'b0, 16'h01FF, 16'h0}    // endpoint is not ready
};

localparam [1:0] IDLE_s = 2'd0;
localparam [1:0] SELF_DB_s = 2'd1;
localparam [1:0] DATA_DB_s = 2'd2;
localparam [1:0] NWR_s = 2'd3;
// incoming packet fields
wire  [7:0] current_tid;
wire  [3:0] current_ftype;
wire  [3:0] current_ttype;
wire  [7:0] current_size;
wire  [1:0] current_prio;
wire [33:0] current_addr;
wire [15:0] current_srcid;
wire [15:0] current_db_info;

reg [15:0] current_db_info_r;
reg [1:0] state;

// NWR signals
wire [7:0] current_nwr_size;
wire [33:0] current_nwr_addr;
reg [7:0] current_nwr_size_r;
reg [33:0] current_nwr_addr_r;
reg [19:0] nwr_recv_byte_cnt;
// request signals

wire treq_advance_condition;
reg tresp_advance_condition;

reg first_beat;
reg generate_a_response;

reg ed_ready;
reg [15:0] log_rst_shift;
wire log_rst_q;

// FIFO signals
wire fifo_clk;
wire fifo_rst;
wire [74:0] fifo_din;
wire fifo_wr_en;
reg fifo_rd_en;
wire [74:0] fifo_dout;
wire fifo_full;
wire fifo_empty;
wire [8:0] fifo_data_cnt;
reg fifo_data_first;

// Debug signals
wire [0:0] tresp_tvalid_ila;
wire [0:0] tresp_tready_ila;
wire [0:0] tresp_tlast_ila;

wire [0:0] treq_tvalid_ila;
wire [0:0] treq_tready_ila;
wire [0:0] treq_tlast_ila;


assign treq_advance_condition = treq_tvalid_in;
assign treq_tready_o = 1'b1;
//tresp_advance_condition = tresp_tready_in && tresp_tvalid_in;

// Generate log reset
always @(posedge log_clk or posedge log_rst) begin
    if (log_rst) begin
        log_rst_shift <= 16'hff;
    end
    else begin
        log_rst_shift <= {log_rst_shift[14:0], 1'b0};
    end
end

assign log_rst_q = log_rst_shift[15];


always @(posedge log_clk) begin
        if (log_rst_q) begin
          first_beat <= 1'b1;
        end
        else if (treq_advance_condition && treq_tlast_in) begin
                  first_beat <= 1'b1;
        end
        else if (treq_advance_condition) begin
          first_beat <= 1'b0;
        end
end

assign current_tid   = treq_tdata_in[63:56];
assign current_ftype = treq_tdata_in[55:52];
assign current_ttype = treq_tdata_in[51:48];
assign current_size  = treq_tdata_in[43:36];
assign current_prio  = treq_tdata_in[46:45] + 2'b01;
assign current_addr  = treq_tdata_in[33:0];
assign current_db_info = treq_tdata_in[31:16];
assign current_srcid = treq_tuser_in[31:16];

assign current_nwr_addr = current_addr;
assign current_nwr_size = treq_tdata_in[43:36];

always @(negedge treq_tvalid_in) begin
        if (current_ftype == DOORB) begin
                $display($time, "Target-> Source: Get a request from source, whose src_id is %x and the inform is %x", current_srcid, current_db_info);
                //$display("Target-> Source: The inform in the request is %x",current_db_info);
        end
end

always @(posedge log_clk ) begin : proc_req_FSM
    if(log_rst_q) begin
        state <= IDLE_s;
        current_db_info_r <= 'h0;
        current_nwr_addr_r <= 'h0;
        current_nwr_size_r <= 'h0;
        nwr_recv_byte_cnt <= 'h0;
    end
    else begin
        tresp_tvalid_o <= 1'b0;
        tresp_tdata_o <= 64'h0;
        tresp_tkeep_o <= 8'h0;
        tresp_tuser_o <= 32'h0;
        tresp_tlast_o <= 1'b0;
        case(state)

            IDLE_s: begin
                nwr_recv_byte_cnt <= 'h0;
                if(nwr_recv_byte_cnt != 'h0) begin
                    $display($time, " Target: The received packet length is %d",nwr_recv_byte_cnt);
                end

                if (treq_tvalid_in && current_ftype == DOORB && current_db_info ==16'h0101) begin
                    state <= SELF_DB_s;
                    current_db_info_r <= 16'h0100;
                end
                else if (treq_tvalid_in && current_ftype == DOORB &&
                            (current_db_info==16'h0200 || current_db_info==16'h0201)) begin
                    state <= DATA_DB_s;
                    current_db_info_r <= current_db_info;
                end
                else if (treq_tvalid_in && current_ftype == NWRITE && current_ttype == TNWR) begin
                    state <= NWR_s;
                    current_nwr_addr_r <= current_nwr_addr;
                    current_nwr_size_r <= current_nwr_size;
                    $display("--------------------------------------------------");
                    $display($time, "Target: Get NWR request from source");
                    $display("Target: The transfer length from source is %d bytes.", (current_nwr_size+1));
                end
                else begin
                    state <= IDLE_s;
                end
            end
            SELF_DB_s: begin
                nwr_recv_byte_cnt <= 'h0;
                $display("Target-> Source: Response to self doorbell request");
                if (tresp_tready_in        && ed_ready_in == 2'h1) begin
                    tresp_tdata_o <= db_instr[64*2-1:64];
                    tresp_tkeep_o <= 8'hff;
                    tresp_tlast_o <= 1'b1;
                    tresp_tvalid_o <= 1'b1;
                    tresp_tuser_o <= {src_id, des_id};
                    state <= IDLE_s;
                end
                else if (tresp_tready_in && ed_ready_in != 2'h1) begin
                    tresp_tdata_o <= db_instr[63:0];
                    tresp_tkeep_o <= 8'hff;
                    tresp_tlast_o <= 1'b1;
                    tresp_tvalid_o <= 1'b1;
                    tresp_tuser_o <= {src_id, des_id};
                    state <= IDLE_s;
                end
                else begin
                    tresp_tvalid_o <= 1'b0;
                    tresp_tdata_o <= 64'h0;
                    tresp_tkeep_o <= 8'h0;
                    tresp_tuser_o <= 32'h0;
                    tresp_tlast_o <= 1'b0;
                    state <=SELF_DB_s;
                end
            end
            DATA_DB_s: begin
                nwr_recv_byte_cnt <= 'h0;
                tresp_tdata_o <= {db_instr[63:32], current_db_info_r, 16'h0};
                tresp_tkeep_o <= 8'hff;
                tresp_tlast_o <= 1'b1;
                tresp_tvalid_o <= 1'b1;
                tresp_tuser_o <= {src_id, des_id};
                state <= IDLE_s;
                current_db_info_r <= 'h0;
                $display($time, "Target-> Source: Response to data integration doorbell request");
            end
            NWR_s: begin
                if (treq_tvalid_in && treq_tkeep_in == 8'hff) begin
                    nwr_recv_byte_cnt[19:3] <= nwr_recv_byte_cnt[19:3] + 17'd1;
                end
                else begin
                    nwr_recv_byte_cnt[19:3] <= nwr_recv_byte_cnt[19:3];
                end
                if(treq_tvalid_in) begin
                    case(treq_tkeep_in)
                        8'h00,8'hff: nwr_recv_byte_cnt[2:0] <= 3'd0;
                        8'h80: nwr_recv_byte_cnt[2:0] <= 3'd1;
                        8'ha0: nwr_recv_byte_cnt[2:0] <= 3'd2;
                        8'he0: nwr_recv_byte_cnt[2:0] <= 3'd3;
                        8'hf0: nwr_recv_byte_cnt[2:0] <= 3'd4;
                        8'hf8: nwr_recv_byte_cnt[2:0] <= 3'd5;
                        8'hfa: nwr_recv_byte_cnt[2:0] <= 3'd6;
                        8'hfe: nwr_recv_byte_cnt[2:0] <= 3'd7;
                        default: nwr_recv_byte_cnt[2:0] <= 3'd0;
                    endcase // treq_tkeep_in
                    if (treq_tlast_in) begin
                        state <= IDLE_s;
                    end
                    else begin
                        state <= NWR_s;
                    end
                end
                else begin
                    nwr_recv_byte_cnt[2:0] <= nwr_recv_byte_cnt[2:0];
                end
            end
        endcase // state
    end
end


assign tresp_tvalid_ila[0] = tresp_tvalid_o;
assign tresp_tready_ila[0] = tresp_tready_in;
assign tresp_tlast_ila[0] = tresp_tlast_o;
assign treq_tvalid_ila[0] = treq_tvalid_in;
assign treq_tlast_ila[0] = treq_tlast_in;
/*
generate
        if (SIM == 0) begin: ila_resp_gen
                ila_resp ila_resp_i (
                .clk(log_clk), // input wire clk
                .probe0(tresp_tvalid_ila), // input wire [0:0]  probe0
                .probe1(tresp_tready_ila), // input wire [0:0]  probe1
                .probe2(tresp_tlast_ila), // input wire [0:0]  probe2
                .probe3(tresp_tdata_o), // input wire [63:0]  probe3
                .probe4(tresp_tkeep_o), // input wire [7:0]  probe4
                .probe5(tresp_tuser_o), // input wire [31:0]  probe5
                .probe6(state), // input wire [1:0]  probe6
                .probe7(treq_tlast_ila),
                .probe8(treq_tvalid_ila),
                .probe9(treq_tdata_in),
                .probe10(treq_tkeep_in),
                .probe11(treq_tuser_in)
        );
        end
endgenerate
*/
/*
reg [63:0] nwr_tdata;
reg [7:0] nwr_tkeep;
reg nwr_tvalid;
reg nwr_tfirst;
reg nwr_tlast;

always @(posedge log_clk) begin : proc_nwr
        if(log_rst_q) begin
                 nwr_tdata_r <= 'h0;
                 nwr_tkeep_r <= 'h0;
                 nwr_tvalid_r <= 'h0;
                 nwr_tfirst <= 'h0;
                 nwr_tlast <= 'h0;
        end
        else begin
                 nwr_tvalid <= treq_tvalid_in;
                 nwr_tfirst <= ~nwr_tvalid & treq_tvalid_in;
                 nwr_tdata <= treq_tdata_in;
                 nwr_tkeep <= treq_tkeep_in;
                 nwr_tlast <= treq_tlast_in;
        end
end

assign fifo_din = {nwr_tvalid, nwr_tfirst, nwr_tkeep, nwr_tlast, nwr_tdata};
*/
/*// Generate a response flag
always @(posedge log_clk) begin
    if (log_rst_q) begin
      generate_a_response <= 1'b0;
    end else if (first_beat && treq_advance_condition) begin
      generate_a_response <= (current_ftype == DOORB);
    end else begin
      generate_a_response <= 1'b0;
    end
  end

always @(posedge log_clk) begin
        if (log_rst_q) begin
                //treq_tready_o <= 1'b1;
                tresp_advance_condition <= 1'b0;
        end
        else begin
                if (generate_a_response) begin
                        tresp_advance_condition <= 1'b1;
                //        treq_tready_o <= 1'b0;
                end
                else begin
                        tresp_advance_condition <= 1'b0;
                end

                if (tresp_advance_condition && tresp_tready_in) begin
                        if (ed_ready_in == 2'h1) begin
                                tresp_tdata_o <= db_instr[64*2-1:64];
                        end
                        else begin
                                tresp_tdata_o <= db_instr[63:0];
                        end
                        tresp_tkeep_o <= 8'hff;
                        tresp_tlast_o <= 1'b1;
                        tresp_tvalid_o <= 1'b1;
                        tresp_tuser_o <= {src_id, des_id};
                        //tresp_advance_condition <= 1'b0;
                end
                else begin
                        //treq_tready_o <= 1'b1;
                        tresp_tvalid_o <= 1'b0;
                        tresp_tdata_o <= 64'h0;
                        tresp_tkeep_o <= 8'h0;
                        tresp_tuser_o <= 32'h0;
                        tresp_tlast_o <= 1'b0;
                        //tresp_advance_condition <= tresp_advance_condition;
                end
        end
end
*/
endmodule
