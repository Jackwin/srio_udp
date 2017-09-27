/*  Author: chunjie Wang
    Date: 2017-06-01
    Description: Self check via Doorbell message.

*/

`timescale 1ns/1ns
module db_req
    #(parameter SIM = 0)
    (
    input log_clk,
    input log_rst,

    input wire [15:0] src_id,
    input wire [15:0] des_id,

    // Before NWR, the system should finish self-check via doorbell
    input wire self_check_in,
    input wire nwr_req_in,
    output reg rapidIO_ready_o,
    input wire link_initialized,

    // Indicate NWR is ready to receive data from user logic
    output reg nwr_ready_o,
    output reg nwr_busy_o,
    output wire nwr_ack_done_o,


    output wire user_tready_o,
    input wire [33:0] user_addr,
    input wire [3:0] user_ftype,
    input wire [3:0] user_ttype,
    input wire [7:0] user_tsize_in,

    input wire [63:0] user_tdata_in,
    input wire user_tvalid_in,
    input wire user_tfirst_in,
    input wire [7:0] user_tkeep_in,
    input wire user_tlast_in,

    //Bytelength

    output wire     error_out,
    // Error 01 : No response to doorbell request
    // Error 10 : No response to data integration request
    output wire [1:0] error_type_o,
    output wire [7:0] error_target_id,

    output reg             ireq_tvalid_o,
    input wire             ireq_tready_in,
    output reg             ireq_tlast_o,
    output reg [63:0]    ireq_tdata_o,
    output reg [7:0]     ireq_tkeep_o,
    output reg [31:0]     ireq_tuser_o,

    input             iresp_tvalid_in,
    output wire        iresp_tready_o,
    input             iresp_tlast_in,
    input      [63:0] iresp_tdata_in,
    input       [7:0] iresp_tkeep_in,
    input      [31:0] iresp_tuser_in
    );
localparam [3:0] DOORB = 4'hA;
localparam [3:0] NWR = 4'h5;

localparam [3:0] TNWR   = 4'h4;

localparam [63:0] db_instr = {
// srcTID  FTYPE  R    R      prio  CRF    R     Info      R
    {8'h00, DOORB, 4'h0, 1'b0, 2'h1, 1'b0, 12'b0, 16'h0101, 16'h0}
};
/*localparam [63:0] nwr_instr = {
    srcTID, nwr, TNWR, 1'b0, 2'h1, 1'b0, (size-1), 2'h0, addr}
};
*/

// FSM signals
localparam [2:0] IDLE_s = 3'h0;
localparam [2:0] DB_REQ_s = 3'h1;
localparam [2:0] DB_RESP_s = 3'h2;
localparam [2:0] NWR_s = 3'h3;
localparam [2:0] INTEG_DB_REQ_s = 3'h4;
localparam [2:0] WAIT_TARGET_ACK_s = 3'd5;
reg [2:0] state;

reg  [15:0] log_rst_shift;
wire        log_rst;

// nwr signals
wire [63:0] nwr_instr;
reg nwr_first_beat;
wire nwr_advance_condition;
wire nwr_done ;
reg nwr_done_r;
wire [7:0] nwr_srcID;
reg [33:0] target_ed_addr;
reg [2:0] nwr_times;

// After the NWR operation, enable doorbell request and send the address (0x0200+n)
reg db_req_ena;
reg [15:0] db_req_inform;

// Update the source ID
reg bit_reverse;

reg dr_req_r1, dr_req_p;

// Timer to wait the data received confirm from target
reg [15:0] timer_cnt;
reg timer_ena;
reg over_time;
wire target_confirm;
wire target_ack;


// Response signals
wire  [7:0] current_resp_tid;
wire  [3:0] current_resp_ftype;
wire  [3:0] current_resp_ttype;
wire  [7:0] current_resp_size;
wire  [1:0] current_resp_prio;
wire [33:0] current_resp_addr;
wire [15:0] current_resp_srcid;
wire [15:0] current_resp_db_info;
wire [15:0] resp_dest_id;
wire [15:0] resp_src_id;

wire get_a_response;
wire target_ready;
wire target_busy;

// FIFO signals
wire fifo_clk;
wire fifo_rst;
wire [74:0] fifo_din;
wire fifo_wr_en;
wire fifo_rd_en;
reg fifo_rd_en_r;
wire [74:0] fifo_dout;
wire fifo_full;
wire fifo_empty;
wire [8:0] fifo_data_cnt;
reg fifo_data_first;


// User logic signals
reg user_tvalid_r;
reg [63:0]     user_tdata_r;
reg user_tlast_r;
reg [7:0] user_tkeep_r;
wire [63:0] current_user_data;
wire current_user_valid;
wire current_user_first;
wire [7:0] current_user_keep;
wire current_user_last;
wire [11:0] current_user_size;

reg [8:0] nwr_byte_cnt;
reg [8:0] nwr_8byte_cnt;
reg [4:0] nwr_packect_transfer_cnt; // A whole packect contains 256 bytes
reg user_data_first;
reg [4:0] packect_transfer_times;
wire [7:0] byte_left;

//Debug

wire [0:0] ireq_tlast_ila, ireq_tvalid_ila, ireq_tready_ila;
wire [0:0] iresp_tlast_ila, iresp_tvalid_ila;

/*
always @(posedge log_clk or posedge log_rst) begin
    if (log_rst)
          log_rst_shift <= 16'hFFFF;
    else
          log_rst_shift <= {log_rst_shift[14:0], 1'b0};
end
assign log_rst = log_rst_shift[15];
*/

always @(posedge log_clk) begin
    if (log_rst) begin
        state <= IDLE_s;
        nwr_ready_o <= 1'b0;
        nwr_busy_o <= 1'b1;
    end
    else begin
        nwr_busy_o <= 1'b1;
        nwr_ready_o <= 1'b0;
        case (state)
        IDLE_s: begin
            nwr_ready_o <= nwr_ready_o;
            if (self_check_in && link_initialized) begin
                state <= DB_REQ_s;
            end
            else if (nwr_req_in && link_initialized) begin
                state <= NWR_s;
                nwr_ready_o <= 1'b0;
            end
            else begin
                state <= IDLE_s;
            end
        end
        DB_REQ_s: begin
            if (ireq_tready_in) begin
                state <= DB_RESP_s;
            end
            else begin
                state <= DB_REQ_s;
            end
        end
        DB_RESP_s: begin
            if (target_ready) begin
                nwr_ready_o    <= 1'b1;
                state <= IDLE_s;
            end
            else if (target_busy) begin
                nwr_busy_o <= 1'b1;
                nwr_ready_o    <= 1'b0;
                state <= IDLE_s;
            end
            else if (over_time) begin
                state <= IDLE_s;
            end
            else begin
                nwr_ready_o <= 1'b0;
                nwr_busy_o <= 1'b0;
                state <= DB_RESP_s;
            end
        end
        NWR_s: begin
            if (nwr_done) begin
                state <= INTEG_DB_REQ_s    ;
            end
            else begin
                state <= NWR_s;
            end
        end
        INTEG_DB_REQ_s: begin
            state <= WAIT_TARGET_ACK_s;
        end
        WAIT_TARGET_ACK_s: begin
            if (target_ack) begin
                state <= IDLE_s;
                $display($time," Source: Data integration confirm from target.");
            end
            else if (over_time) begin
                state <= IDLE_s;
                $display($time," Source: No data integration confirm from target.");

            end
            else begin
                state <= WAIT_TARGET_ACK_s;
            end
        end

        default: begin
            state <= IDLE_s;
        end
        endcase

    end
end

assign iresp_tready_o = 1'b1;

always @(*) begin
    ireq_tvalid_o = 1'b0;
    ireq_tlast_o = 1'b0;
    ireq_tdata_o = 1'b0;
    ireq_tkeep_o = 8'hff;
    ireq_tuser_o = 1'b0;
    ireq_tvalid_o = 1'b0;
    timer_ena = 1'b0;
    rapidIO_ready_o = 1'b1;
    case (state)
        IDLE_s: begin
            ireq_tdata_o = 1'b0;
            ireq_tvalid_o = 1'b0;
            ireq_tkeep_o = 8'hff;
            ireq_tlast_o = 1'b0;
            ireq_tuser_o = 1'b0;
            rapidIO_ready_o = 1'b1;
            timer_ena = 1'b0;
        //    db_req_ena <= db_req_ena;
        end
        DB_REQ_s: begin
            rapidIO_ready_o = 1'b0;
            timer_ena = 1'b0;
            if (ireq_tready_in) begin
                // Send self-check
                ireq_tdata_o = db_instr[63:0];
                ireq_tvalid_o = 1'b1;
                ireq_tkeep_o = 8'hff;
                ireq_tlast_o = 1'b1;
                ireq_tuser_o = {src_id, des_id};
                $display($time, " Source->Target: Self doorbell check");
            end
            else begin
                ireq_tdata_o = 1'b0;
                ireq_tvalid_o = 1'b0;
                ireq_tkeep_o = 8'hff;
                ireq_tlast_o = 1'b0;
                ireq_tuser_o = 1'b0;
                rapidIO_ready_o = 1'b1;
            end
        end
        DB_RESP_s: begin
            rapidIO_ready_o = 1'b0;
            ireq_tdata_o = 1'b0;
            ireq_tvalid_o = 1'b0;
            ireq_tkeep_o = 8'hff;
            ireq_tlast_o = 1'b0;
            ireq_tuser_o = 1'b0;
            timer_ena = 1'b1;
        end
        NWR_s: begin
            rapidIO_ready_o = 1'b0;
            timer_ena = 1'b0;
            ireq_tuser_o = {src_id, des_id};

            ireq_tdata_o = (current_user_valid && current_user_first && ireq_tready_in) ? {nwr_srcID, NWR, TNWR,
                        1'b0, 2'h1, 1'b0, current_user_data[7:0] , 2'h0, target_ed_addr}
                        : ((current_user_valid && ~current_user_first && ireq_tready_in) ? current_user_data
                        : ((!ireq_tready_in) ? ireq_tdata_o : 'h0)) ;
            ireq_tvalid_o = current_user_valid ;
            ireq_tkeep_o = current_user_keep ;
            ireq_tlast_o = current_user_last;
            // In one transfer, called as packet here, the maximum length is 256 bytes.

            // The maximum transfer length is 256-byte, and the unpack operation is moved to input_reader.v
            /*
            if (nwr_packect_transfer_cnt == packect_transfer_times) begin
                ireq_tlast_o = current_user_last;

            end
            else if (nwr_8byte_cnt == 8'd31) begin  // The end of a 64-Dword packect
                ireq_tlast_o = 1'b1;

            end
            else begin
                ireq_tlast_o = 1'b0;
            end
            */
        end // NWR_s:
        INTEG_DB_REQ_s: begin
            if (ireq_tready_in) begin
                ireq_tdata_o = {db_instr[63:32],db_req_inform,16'h0};
                ireq_tvalid_o = 1'b1;
                ireq_tkeep_o = 8'hff;
                ireq_tlast_o = 1'b1;
                ireq_tuser_o = {src_id, des_id};
                $display($time, "Source->Target: Data integration doorbell reqest, and the address is %x", db_req_inform);
            end
            //$display("Source->Target: Address is %x",db_req_inform);
        end
        WAIT_TARGET_ACK_s: begin
            timer_ena = 1'b1;
            ireq_tdata_o = 1'b0;
            ireq_tvalid_o = 1'b0;
            ireq_tkeep_o = 8'hff;
            ireq_tlast_o = 1'b0;
            ireq_tuser_o = 1'b0;
            rapidIO_ready_o = 1'b1;
        end
        default: begin
            rapidIO_ready_o <= 1'b1;
            ireq_tdata_o = 1'b0;
            ireq_tvalid_o = 1'b0;
            ireq_tkeep_o = 8'hff;
            ireq_tlast_o = 1'b0;
            ireq_tuser_o = 1'b0;
            rapidIO_ready_o = 1'b1;
            timer_ena = 1'b0;
        end
    endcase
end

always @(posedge log_clk) begin : proc_timer
    if(log_rst) begin
         timer_cnt <= 0;
         over_time <= 1'b0;
    end
    else if (timer_ena) begin
        if (timer_cnt == 10'hffff) begin
            over_time <= 1'b1;
        end
        else begin
            timer_cnt <= timer_cnt + 'h1;
            over_time <= 1'b0;
        end
    end
    else begin
        timer_cnt <= 'h0;
        over_time <= 1'b0;
    end
end

/*
always @(posedge log_clk) begin : proc_transfer_timers
    if(log_rst) begin
        packect_transfer_times <= 0;
    end else if (state == NWR_s) begin
        if (current_user_valid && current_user_first || current_user_last) begin
            // 256 bytes as one whole packet
            packect_transfer_times = current_user_data[12:8];
        end
        else begin
            packect_transfer_times = packect_transfer_times;
        end
    end
end
*/
always @(posedge log_clk) begin : proc_nwr_write_cnt
    if(log_rst) begin
        nwr_8byte_cnt <= 0;
        nwr_packect_transfer_cnt <= 'h0;
    end
    else if (state == NWR_s) begin
        if (current_user_first && current_user_valid) begin
            nwr_8byte_cnt <= 'h0;
            nwr_packect_transfer_cnt <= 'h0;
            end
        else if (current_user_valid && ireq_tready_in) begin
            if (nwr_8byte_cnt == 8'd31) begin
                nwr_packect_transfer_cnt <= nwr_packect_transfer_cnt + 4'h1;
                nwr_8byte_cnt <= 'h0;
            end
            else begin
                nwr_8byte_cnt <= nwr_8byte_cnt + 8'h1;
            end
        end
        else begin
            nwr_8byte_cnt <= nwr_8byte_cnt;
            nwr_packect_transfer_cnt <= nwr_packect_transfer_cnt;
        end
    end
end

assign fifo_rd_en = (state == NWR_s && ~fifo_empty && ireq_tready_in) ? 1'b1 : 1'b0;

always @(posedge log_clk) begin
    if (log_rst) begin
        fifo_rd_en_r <= 1'b0;
    end
    else begin
        fifo_rd_en_r <= fifo_rd_en;
    end
end

// One NWR opearation is done
// When the last dat in reg logic is it is nwr_done
/*asreg nwr_done _packect_transfer_cnt == packect_transfer_times &&
                    ((nwr_8byte_cnt[7:3] == current_user_size[7:3] - 1 && current_user_size[2:0] == 'h0)
                    || (nwr_8byte_cnt[7:3] == current_user_size[7:3] && current_user_size[2:0] != 'h0)));reg
                    */


// Using ireq_last to indicate the packet boundary. When the number of transferred



assign nwr_done = (state == NWR_s) ? ireq_tlast_o : 1'b0;
assign error_out = over_time;
assign error_target_id = des_id;
assign error_type_o = (state == DB_RESP_s && over_time) ? 2'h1 :
                        ((state == WAIT_TARGET_ACK_s && over_time) ? 2'h2 : 2'h0);

always @(posedge log_clk) begin
    if (log_rst) begin
        nwr_done_r <= 1'b0;
    end
    else begin
        nwr_done_r <= nwr_done;
    end
end

always @(posedge log_clk) begin
    if (state == NWR_s && current_user_first) begin

        $display($time, " Source->Target: Now sending NWR packet with the length being %d and target ID being %x", current_user_size+1,target_ed_addr);
        //$display("Source->Target: The target ID is %x", target_ed_addr);
    end

    if (error_out && error_type_o == 2'h1) begin
        $display($time, " No response to doorbell request");
    end
    else if (error_out && error_type_o == 2'h2) begin
        $display($time, " No response to data integration doorbell response.");
    end
end


// nwr_srcID control logic
always @(posedge log_clk ) begin
    if (log_rst) begin
        bit_reverse <= 'h0;
    end
    else begin
        if (target_ack) begin
            bit_reverse <= ~bit_reverse;
        end
        else begin
            bit_reverse <= bit_reverse;
        end
    end
end



assign nwr_srcID = {7'h0, bit_reverse};

// Target endpoint address nwr_srcID x 1M
always @(posedge log_clk) begin
    if (log_rst) begin
        target_ed_addr <= 'h0;
        db_req_inform <= 0;
    end
    else begin
        if (~bit_reverse) begin
            target_ed_addr <= 'h0;
            // Doorbell content is 0x0200 + n (n=0,1)
            db_req_inform <= 16'h0200 + 16'h1;
        end
        else begin
            target_ed_addr    <= (34'h1 << 20);
            db_req_inform <= 16'h0200;
        end
    end
end

// Response signals

assign current_resp_tid   = iresp_tdata_in[63:56];
assign current_resp_ftype = iresp_tdata_in[55:52];
assign current_resp_ttype = iresp_tdata_in[51:48];
assign current_resp_size  = iresp_tdata_in[43:36];
assign current_resp_prio  = iresp_tdata_in[46:45] + 2'b01; // Response priority should be increased by 1
assign current_resp_addr  = iresp_tdata_in[33:0];
assign current_resp_db_info = iresp_tdata_in[31:16];
assign current_resp_srcid = iresp_tuser_in[31:16];

assign get_a_response =  (current_resp_ftype == DOORB && current_resp_srcid == 8'hf0 && iresp_tvalid_in) ? 1'b1: 1'b0;
// Indicate the requested endpoint is ready
assign target_ready = (get_a_response && current_resp_db_info == 16'h0100) ? 1'b1: 1'b0;
assign target_busy =  (get_a_response && current_resp_db_info == 16'h01ff) ? 1'b1 : 1'b0;
assign target_confirm = (get_a_response && current_resp_db_info == db_req_inform) ? 1'b1 : 1'b0;
assign target_ack = target_confirm;
// Indicate a NWRITE and data integration is done successfully
assign nwr_ack_done_o = target_confirm;

always @(posedge get_a_response) begin
    //if (get_a_response) begin
    $display($time, " Source->Target: Get a response from target and the src_id is %x and the inform is %x.", current_resp_srcid,current_resp_db_info);
    //$display("Source->Target: The inform in the response is %x.",current_resp_db_info);
end

always @(posedge target_ready) begin
    $display($time, " Source->Target: The target endpoint is ready.");
end
always @(posedge target_busy) begin
    $display($time, " Source->Target: The target endpoint is busy.");
end

/*
1. consider about the relationship of user size and packet size
2. the times of a whole packet transfer and the remaining transfer
3. update the nwr_srcID
*/


assign nwr_advance_condition = ireq_tready_in && ireq_tvalid_o && (state == NWR_s);

always @(posedge log_clk) begin
    if (log_rst) begin
        nwr_first_beat <= 1'b1;
    end
    else begin
        if (nwr_advance_condition && ireq_tlast_o) begin
            nwr_first_beat <= 1'b1;
        end
        else if (nwr_advance_condition) begin
            nwr_first_beat <= 1'b0;
        end
    end
end

//Logic for user data

assign user_tready_o = ~fifo_full;
assign fifo_clk = log_clk;
assign fifo_rst = log_rst;
assign fifo_din = user_tfirst_in ? {1'b1, user_tfirst_in, user_tkeep_r, user_tlast_r, {56'h0, {user_tsize_in}}}
                                 : {user_tvalid_r, 1'b0, user_tkeep_r, user_tlast_r, user_tdata_r};
assign fifo_wr_en = user_tvalid_in || user_tvalid_r;

assign current_user_valid = fifo_dout[74];
assign current_user_first = fifo_dout[73];
assign current_user_keep = fifo_dout[72:65];
assign current_user_last =  fifo_dout[64];
assign current_user_data = fifo_dout[63:0];
//assign current_user_size = (user_data_first) ? user_tdata_r[7:0]  : current_user_size;
assign current_user_size = (current_user_first) ? current_user_data[7:0]  : current_user_size;

//assign packect_transfer_times = current_user_size[11:8];
assign byte_left = current_user_size[7:0];

always @(posedge fifo_clk) begin
    if (fifo_rst) begin
        user_tvalid_r <= 1'b0;
        user_tdata_r <= 1'b0;
        user_tlast_r <= 1'b0;
        user_tkeep_r <= 'h0;
    end
    else begin
        user_tvalid_r <= user_tvalid_in;
        user_data_first <= ~user_tvalid_r & user_tvalid_in;

        fifo_data_first    <= ~user_tvalid_r & user_tvalid_in;

        user_tdata_r <= user_tdata_in;
        user_tkeep_r <= user_tkeep_in;
        user_tlast_r <= user_tlast_in;
    end
end

fifo_75x512 user_data_fifo (
  .clk(fifo_clk),                // input wire clk
  .srst(fifo_rst),              // input wire srst
  .din(fifo_din),                // input wire [65 : 0] din
  .wr_en(fifo_wr_en),            // input wire wr_en
  .rd_en(fifo_rd_en),            // input wire rd_en
  .dout(fifo_dout),              // output wire [65 : 0] dout
  .full(fifo_full),              // output wire full
  .empty(fifo_empty),            // output wire empty
  .data_count(fifo_data_cnt)  // output wire [8 : 0] data_count
);
generate if (!SIM) begin: ila_req_gen

    assign ireq_tlast_ila[0] = ireq_tlast_o;
    assign ireq_tvalid_ila[0] = ireq_tvalid_o;
    assign ireq_tready_ila[0] = ireq_tready_in;

    assign iresp_tlast_ila[0] = iresp_tlast_in;
    assign iresp_tvalid_ila[0] = iresp_tvalid_in;

        ila_req ila_req_i (
            .clk(log_clk),
            .probe0(ireq_tvalid_o),
            .probe1(ireq_tlast_o),
            .probe2(ireq_tdata_o),
            .probe3(ireq_tkeep_o),
            .probe4(ireq_tuser_o),

            .probe5(iresp_tvalid_ila),
            .probe6(iresp_tlast_ila),
            .probe7(iresp_tdata_in),
            .probe8(iresp_tkeep_in),
            .probe9(iresp_tuser_in),
            .probe10(state),
            .probe11(ireq_tready_ila)
        );
    end
    endgenerate

endmodule

