//
// (c) Copyright 2010 - 2014 Xilinx, Inc. All rights reserved.
//
//                                                                 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// 	PART OF THIS FILE AT ALL TIMES.                                
//----------------------------------------------------------------------
//
// SRIO_QUICK_START
// Description:
// This module sends a fixed set of instructions to the configuration
// register space, both local and remote.
//
// Hierarchy:
// SRIO_EXAMPLE_TOP
//   |____> SRIO_DUT
//   |____> SRIO_STATISTICS
//   |____> SRIO_REPORT
//   |____> SRIO_REQUEST_GEN
//   |____> SRIO_RESPONSE_GEN
//   |____> SRIO_QUICK_START
//
// ---------------------------------------------------------------------

`timescale 1ps/1ps

module srio_quick_start_srio_gen2_0 (
  input             log_clk,
  input             log_rst,

  output reg        maintr_awvalid,
  input             maintr_awready,
  output     [31:0] maintr_awaddr,

  output reg        maintr_wvalid,
  input             maintr_wready,
  output     [31:0] maintr_wdata,
  input             maintr_bvalid,
  output            maintr_bready,
  input       [1:0] maintr_bresp,

  output reg        maintr_arvalid,
  input             maintr_arready,
  output     [31:0] maintr_araddr,

  input             maintr_rvalid,
  output            maintr_rready,
  input      [31:0] maintr_rdata,
  input       [1:0] maintr_rresp,

  input             go,
  input       [3:0] user_hop,
  input             user_inst,
  input      [23:0] user_addr,
  input      [31:0] user_data,

  input             link_initialized,
  output reg        maint_done,
  output reg        maint_autocheck_error
 );


  // {{{ local parameters -----------------
  localparam [8:0] STARTING_ADDRESS       = 9'h0;
  localparam       NUMBER_OF_INSTRUCTIONS = 20;

  localparam       READ      = 1'b1;
  localparam       WRITE     = 1'b0;
  localparam       LOCAL     = 1'b0;
  localparam       REMTE     = 1'b1;

  localparam [3:0] MAINT     = 4'h8;

  localparam [3:0] RDREQ     = 4'h0;
  localparam [3:0] WRREQ     = 4'h1;

  localparam [7:0] HOP_LOCAL = 8'h00;
  localparam [7:0] HOP_REMTE = 8'hFF;


  `include "maintenance_list.vh"
  // }}} End local parameters -------------


  // {{{ wire declarations ----------------
  reg  [15:0] log_rst_shift;
  wire        log_rst_q = log_rst_shift[15];

  reg  [10:0] link_initialized_cnt;
  wire        link_initialized_delay = link_initialized_cnt[10];

  wire [63:0] maint_data_out_d;
  reg  [61:0] maint_data_out; // upper 63:62 bits unused
  reg   [8:0] maint_address;
  reg         go_q;
  wire        go_rose;

  wire        maint_req_advance_condition  = (maintr_awready && maintr_awvalid) ||
                                             (maintr_arready && maintr_arvalid);
  wire        maint_bresp_advance_condition  = (maintr_bready && maintr_bvalid);
  wire        maint_resp_advance_condition   = (maintr_rready && maintr_rvalid);

  reg         last_packet_beat_q, last_packet_beat_qq, last_packet_beat_qqq;
  reg  [15:0] instruction_cnt;
  wire [32:0] data_mask = { {8{maint_data_out[3]}}, {8{maint_data_out[2]}},
                            {8{maint_data_out[1]}}, {8{maint_data_out[0]}} };
  // }}} End wire declarations ------------


  // {{{ Common-use Signals ---------------


  always @(posedge log_clk or posedge log_rst) begin
    if (log_rst)
      log_rst_shift <= 16'hFFFF;
    else
      log_rst_shift <= {log_rst_shift[14:0], 1'b0};
  end

  always @(posedge log_clk) begin
    if (log_rst_q) begin
      last_packet_beat_q       <= 1'b1;
      last_packet_beat_qq      <= 1'b1;
      last_packet_beat_qqq     <= 1'b1;
      go_q                     <= 1'b0;
    end else begin
      last_packet_beat_q       <= maint_resp_advance_condition || maint_bresp_advance_condition;
      last_packet_beat_qq      <= last_packet_beat_q;
      last_packet_beat_qqq     <= last_packet_beat_qq || !link_initialized_delay;
      go_q                     <= go;
    end
  end

  // put a sufficient delay on the initialization to improve simulation time.
  // Not needed for actual hardware but does no damage if kept.
  always @(posedge log_clk) begin
    if (log_rst_q) begin
      link_initialized_cnt <= 0;
    end else if (link_initialized && !link_initialized_delay) begin
      link_initialized_cnt <= link_initialized_cnt + 1;
    end else if (!link_initialized) begin
      link_initialized_cnt <= 0;
    end
  end

  assign go_rose = go && !go_q;
  // }}} End Common-use Signals -----------


  // {{{ Request Packet Formatter ---------
  always @(posedge log_clk) begin
    if (log_rst_q) begin
      maint_address <= STARTING_ADDRESS;
    end else if (maint_resp_advance_condition || maint_bresp_advance_condition) begin
      maint_address <= maint_address + 1;
    end
  end

  assign maintr_wdata = go ? user_data : maint_data_out[35:4];

  assign maintr_bready = 1'b1;
  assign maintr_rready = 1'b1;

  assign maintr_araddr = go ? { 4'h0, user_hop, user_addr} : maint_data_out[61:37];
  assign maintr_awaddr = go ? { 4'h0, user_hop, user_addr} : maint_data_out[61:37];

  always @(posedge log_clk) begin
    if (log_rst_q) begin
      maintr_awvalid   <= 1'b0;
      maintr_wvalid    <= 1'b0;
      maintr_arvalid   <= 1'b0;
      instruction_cnt  <= 16'h0;
    end else if (link_initialized_delay &&
                 (instruction_cnt < NUMBER_OF_INSTRUCTIONS && last_packet_beat_qqq) || go_rose) begin
      maintr_awvalid   <= go ? user_inst == WRITE : maint_data_out[36] == WRITE;
      maintr_wvalid    <= go ? user_inst == WRITE : maint_data_out[36] == WRITE;
      maintr_arvalid   <= go ? user_inst == READ  : maint_data_out[36] == READ;
    end else if (maint_req_advance_condition) begin
      maintr_awvalid   <= 1'b0;
      maintr_wvalid    <= 1'b0;
      maintr_arvalid   <= 1'b0;
      instruction_cnt  <= instruction_cnt + 1;
    end else if (instruction_cnt == NUMBER_OF_INSTRUCTIONS) begin
      maintr_awvalid   <= 1'b0;
      maintr_wvalid    <= 1'b0;
      maintr_arvalid   <= 1'b0;
    end
  end
  // }}} End Request Packet Formatter -----

  // {{{ Request generation ---------------
  RAMB36SDP #(
   .SIM_COLLISION_CHECK("NONE"),
   .EN_ECC_READ("FALSE"),
   .EN_ECC_WRITE("FALSE"),

   .INIT_00({MAINTENANCE3  , MAINTENANCE2  , MAINTENANCE1  , MAINTENANCE0}  ),
   .INIT_01({MAINTENANCE7  , MAINTENANCE6  , MAINTENANCE5  , MAINTENANCE4}  ),
   .INIT_02({MAINTENANCE11 , MAINTENANCE10 , MAINTENANCE9  , MAINTENANCE8}  ),
   .INIT_03({MAINTENANCE15 , MAINTENANCE14 , MAINTENANCE13 , MAINTENANCE12} ),
   .INIT_04({MAINTENANCE19 , MAINTENANCE18 , MAINTENANCE17 , MAINTENANCE16} ),
   .INIT_05({MAINTENANCE23 , MAINTENANCE22 , MAINTENANCE21 , MAINTENANCE20} ),
   .INIT_06({MAINTENANCE27 , MAINTENANCE26 , MAINTENANCE25 , MAINTENANCE24} ),
   .INIT_07({MAINTENANCE31 , MAINTENANCE30 , MAINTENANCE29 , MAINTENANCE28} ),
   .INIT_08({MAINTENANCE35 , MAINTENANCE34 , MAINTENANCE33 , MAINTENANCE32} ),
   .INIT_09({MAINTENANCE39 , MAINTENANCE38 , MAINTENANCE37 , MAINTENANCE36} ),
   .INIT_0A({MAINTENANCE43 , MAINTENANCE42 , MAINTENANCE41 , MAINTENANCE40} ),
   .INIT_0B({MAINTENANCE47 , MAINTENANCE46 , MAINTENANCE45 , MAINTENANCE44} ),
   .INIT_0C({MAINTENANCE51 , MAINTENANCE50 , MAINTENANCE49 , MAINTENANCE48} ),
   .INIT_0D({MAINTENANCE55 , MAINTENANCE54 , MAINTENANCE53 , MAINTENANCE52} ),
   .INIT_0E({MAINTENANCE59 , MAINTENANCE58 , MAINTENANCE57 , MAINTENANCE56} ),
   .INIT_0F({MAINTENANCE63 , MAINTENANCE62 , MAINTENANCE61 , MAINTENANCE60} ),
   .INIT_10({MAINTENANCE67 , MAINTENANCE66 , MAINTENANCE65 , MAINTENANCE64} ),
   .INIT_11({MAINTENANCE71 , MAINTENANCE70 , MAINTENANCE69 , MAINTENANCE68} ),
   .INIT_12({MAINTENANCE75 , MAINTENANCE74 , MAINTENANCE73 , MAINTENANCE72} ),
   .INIT_13({MAINTENANCE79 , MAINTENANCE78 , MAINTENANCE77 , MAINTENANCE76} ),
   .INIT_14({MAINTENANCE83 , MAINTENANCE82 , MAINTENANCE81 , MAINTENANCE80} ),
   .INIT_15({MAINTENANCE87 , MAINTENANCE86 , MAINTENANCE85 , MAINTENANCE84} ),
   .INIT_16({MAINTENANCE91 , MAINTENANCE90 , MAINTENANCE89 , MAINTENANCE88} ),
   .INIT_17({MAINTENANCE95 , MAINTENANCE94 , MAINTENANCE93 , MAINTENANCE92} ),
   .INIT_18({MAINTENANCE99 , MAINTENANCE98 , MAINTENANCE97 , MAINTENANCE96} ),
   .INIT_19({MAINTENANCE103, MAINTENANCE102, MAINTENANCE101, MAINTENANCE100}),
   .INIT_1A({MAINTENANCE107, MAINTENANCE106, MAINTENANCE105, MAINTENANCE104}),
   .INIT_1B({MAINTENANCE111, MAINTENANCE110, MAINTENANCE109, MAINTENANCE108}),
   .INIT_1C({MAINTENANCE115, MAINTENANCE114, MAINTENANCE113, MAINTENANCE112}),
   .INIT_1D({MAINTENANCE119, MAINTENANCE118, MAINTENANCE117, MAINTENANCE116}),
   .INIT_1E({MAINTENANCE123, MAINTENANCE122, MAINTENANCE121, MAINTENANCE120}),
   .INIT_1F({MAINTENANCE127, MAINTENANCE126, MAINTENANCE125, MAINTENANCE124}),
   .INIT_20({MAINTENANCE131, MAINTENANCE130, MAINTENANCE129, MAINTENANCE128}),
   .INIT_21({MAINTENANCE135, MAINTENANCE134, MAINTENANCE133, MAINTENANCE132}),
   .INIT_22({MAINTENANCE139, MAINTENANCE138, MAINTENANCE137, MAINTENANCE136}),
   .INIT_23({MAINTENANCE143, MAINTENANCE142, MAINTENANCE141, MAINTENANCE140}),
   .INIT_24({MAINTENANCE147, MAINTENANCE146, MAINTENANCE145, MAINTENANCE144}),
   .INIT_25({MAINTENANCE151, MAINTENANCE150, MAINTENANCE149, MAINTENANCE148}),
   .INIT_26({MAINTENANCE155, MAINTENANCE154, MAINTENANCE153, MAINTENANCE152}),
   .INIT_27({MAINTENANCE159, MAINTENANCE158, MAINTENANCE157, MAINTENANCE156}),
   .INIT_28({MAINTENANCE163, MAINTENANCE162, MAINTENANCE161, MAINTENANCE160}),
   .INIT_29({MAINTENANCE167, MAINTENANCE166, MAINTENANCE165, MAINTENANCE164}),
   .INIT_2A({MAINTENANCE171, MAINTENANCE170, MAINTENANCE169, MAINTENANCE168}),
   .INIT_2B({MAINTENANCE175, MAINTENANCE174, MAINTENANCE173, MAINTENANCE172}),
   .INIT_2C({MAINTENANCE179, MAINTENANCE178, MAINTENANCE177, MAINTENANCE176}),
   .INIT_2D({MAINTENANCE183, MAINTENANCE182, MAINTENANCE181, MAINTENANCE180}),
   .INIT_2E({MAINTENANCE187, MAINTENANCE186, MAINTENANCE185, MAINTENANCE184}),
   .INIT_2F({MAINTENANCE191, MAINTENANCE190, MAINTENANCE189, MAINTENANCE188}),
   .INIT_30({MAINTENANCE195, MAINTENANCE194, MAINTENANCE193, MAINTENANCE192}),
   .INIT_31({MAINTENANCE199, MAINTENANCE198, MAINTENANCE197, MAINTENANCE196}),
   .INIT_32({MAINTENANCE203, MAINTENANCE202, MAINTENANCE201, MAINTENANCE200}),
   .INIT_33({MAINTENANCE207, MAINTENANCE206, MAINTENANCE205, MAINTENANCE204}),
   .INIT_34({MAINTENANCE211, MAINTENANCE210, MAINTENANCE209, MAINTENANCE208}),
   .INIT_35({MAINTENANCE215, MAINTENANCE214, MAINTENANCE213, MAINTENANCE212}),
   .INIT_36({MAINTENANCE219, MAINTENANCE218, MAINTENANCE217, MAINTENANCE216}),
   .INIT_37({MAINTENANCE223, MAINTENANCE222, MAINTENANCE221, MAINTENANCE220}),
   .INIT_38({MAINTENANCE227, MAINTENANCE226, MAINTENANCE225, MAINTENANCE224}),
   .INIT_39({MAINTENANCE231, MAINTENANCE230, MAINTENANCE229, MAINTENANCE228}),
   .INIT_3A({MAINTENANCE235, MAINTENANCE234, MAINTENANCE233, MAINTENANCE232}),
   .INIT_3B({MAINTENANCE239, MAINTENANCE238, MAINTENANCE237, MAINTENANCE236}),
   .INIT_3C({MAINTENANCE243, MAINTENANCE242, MAINTENANCE241, MAINTENANCE240}),
   .INIT_3D({MAINTENANCE247, MAINTENANCE246, MAINTENANCE245, MAINTENANCE244}),
   .INIT_3E({MAINTENANCE251, MAINTENANCE250, MAINTENANCE249, MAINTENANCE248}),
   .INIT_3F({MAINTENANCE255, MAINTENANCE254, MAINTENANCE253, MAINTENANCE252}),
   .INIT_40({MAINTENANCE259, MAINTENANCE258, MAINTENANCE257, MAINTENANCE256}),
   .INIT_41({MAINTENANCE263, MAINTENANCE262, MAINTENANCE261, MAINTENANCE260}),
   .INIT_42({MAINTENANCE267, MAINTENANCE266, MAINTENANCE265, MAINTENANCE264}),
   .INIT_43({MAINTENANCE271, MAINTENANCE270, MAINTENANCE269, MAINTENANCE268}),
   .INIT_44({MAINTENANCE275, MAINTENANCE274, MAINTENANCE273, MAINTENANCE272}),
   .INIT_45({MAINTENANCE279, MAINTENANCE278, MAINTENANCE277, MAINTENANCE276}),
   .INIT_46({MAINTENANCE283, MAINTENANCE282, MAINTENANCE281, MAINTENANCE280}),
   .INIT_47({MAINTENANCE287, MAINTENANCE286, MAINTENANCE285, MAINTENANCE284}),
   .INIT_48({MAINTENANCE291, MAINTENANCE290, MAINTENANCE289, MAINTENANCE288}),
   .INIT_49({MAINTENANCE295, MAINTENANCE294, MAINTENANCE293, MAINTENANCE292}),
   .INIT_4A({MAINTENANCE299, MAINTENANCE298, MAINTENANCE297, MAINTENANCE296}),
   .INIT_4B({MAINTENANCE303, MAINTENANCE302, MAINTENANCE301, MAINTENANCE300}),
   .INIT_4C({MAINTENANCE307, MAINTENANCE306, MAINTENANCE305, MAINTENANCE304}),
   .INIT_4D({MAINTENANCE311, MAINTENANCE310, MAINTENANCE309, MAINTENANCE308}),
   .INIT_4E({MAINTENANCE315, MAINTENANCE314, MAINTENANCE313, MAINTENANCE312}),
   .INIT_4F({MAINTENANCE319, MAINTENANCE318, MAINTENANCE317, MAINTENANCE316}),
   .INIT_50({MAINTENANCE323, MAINTENANCE322, MAINTENANCE321, MAINTENANCE320}),
   .INIT_51({MAINTENANCE327, MAINTENANCE326, MAINTENANCE325, MAINTENANCE324}),
   .INIT_52({MAINTENANCE331, MAINTENANCE330, MAINTENANCE329, MAINTENANCE328}),
   .INIT_53({MAINTENANCE335, MAINTENANCE334, MAINTENANCE333, MAINTENANCE332}),
   .INIT_54({MAINTENANCE339, MAINTENANCE338, MAINTENANCE337, MAINTENANCE336}),
   .INIT_55({MAINTENANCE343, MAINTENANCE342, MAINTENANCE341, MAINTENANCE340}),
   .INIT_56({MAINTENANCE347, MAINTENANCE346, MAINTENANCE345, MAINTENANCE344}),
   .INIT_57({MAINTENANCE351, MAINTENANCE350, MAINTENANCE349, MAINTENANCE348}),
   .INIT_58({MAINTENANCE355, MAINTENANCE354, MAINTENANCE353, MAINTENANCE352}),
   .INIT_59({MAINTENANCE359, MAINTENANCE358, MAINTENANCE357, MAINTENANCE356}),
   .INIT_5A({MAINTENANCE363, MAINTENANCE362, MAINTENANCE361, MAINTENANCE360}),
   .INIT_5B({MAINTENANCE367, MAINTENANCE366, MAINTENANCE365, MAINTENANCE364}),
   .INIT_5C({MAINTENANCE371, MAINTENANCE370, MAINTENANCE369, MAINTENANCE368}),
   .INIT_5D({MAINTENANCE375, MAINTENANCE374, MAINTENANCE373, MAINTENANCE372}),
   .INIT_5E({MAINTENANCE379, MAINTENANCE378, MAINTENANCE377, MAINTENANCE376}),
   .INIT_5F({MAINTENANCE383, MAINTENANCE382, MAINTENANCE381, MAINTENANCE380}),
   .INIT_60({MAINTENANCE387, MAINTENANCE386, MAINTENANCE385, MAINTENANCE384}),
   .INIT_61({MAINTENANCE391, MAINTENANCE390, MAINTENANCE389, MAINTENANCE388}),
   .INIT_62({MAINTENANCE395, MAINTENANCE394, MAINTENANCE393, MAINTENANCE392}),
   .INIT_63({MAINTENANCE399, MAINTENANCE398, MAINTENANCE397, MAINTENANCE396}),
   .INIT_64({MAINTENANCE403, MAINTENANCE402, MAINTENANCE401, MAINTENANCE400}),
   .INIT_65({MAINTENANCE407, MAINTENANCE406, MAINTENANCE405, MAINTENANCE404}),
   .INIT_66({MAINTENANCE411, MAINTENANCE410, MAINTENANCE409, MAINTENANCE408}),
   .INIT_67({MAINTENANCE415, MAINTENANCE414, MAINTENANCE413, MAINTENANCE412}),
   .INIT_68({MAINTENANCE419, MAINTENANCE418, MAINTENANCE417, MAINTENANCE416}),
   .INIT_69({MAINTENANCE423, MAINTENANCE422, MAINTENANCE421, MAINTENANCE420}),
   .INIT_6A({MAINTENANCE427, MAINTENANCE426, MAINTENANCE425, MAINTENANCE424}),
   .INIT_6B({MAINTENANCE431, MAINTENANCE430, MAINTENANCE429, MAINTENANCE428}),
   .INIT_6C({MAINTENANCE435, MAINTENANCE434, MAINTENANCE433, MAINTENANCE432}),
   .INIT_6D({MAINTENANCE439, MAINTENANCE438, MAINTENANCE437, MAINTENANCE436}),
   .INIT_6E({MAINTENANCE443, MAINTENANCE442, MAINTENANCE441, MAINTENANCE440}),
   .INIT_6F({MAINTENANCE447, MAINTENANCE446, MAINTENANCE445, MAINTENANCE444}),
   .INIT_70({MAINTENANCE451, MAINTENANCE450, MAINTENANCE449, MAINTENANCE448}),
   .INIT_71({MAINTENANCE455, MAINTENANCE454, MAINTENANCE453, MAINTENANCE452}),
   .INIT_72({MAINTENANCE459, MAINTENANCE458, MAINTENANCE457, MAINTENANCE456}),
   .INIT_73({MAINTENANCE463, MAINTENANCE462, MAINTENANCE461, MAINTENANCE460}),
   .INIT_74({MAINTENANCE467, MAINTENANCE466, MAINTENANCE465, MAINTENANCE464}),
   .INIT_75({MAINTENANCE471, MAINTENANCE470, MAINTENANCE469, MAINTENANCE468}),
   .INIT_76({MAINTENANCE475, MAINTENANCE474, MAINTENANCE473, MAINTENANCE472}),
   .INIT_77({MAINTENANCE479, MAINTENANCE478, MAINTENANCE477, MAINTENANCE476}),
   .INIT_78({MAINTENANCE483, MAINTENANCE482, MAINTENANCE481, MAINTENANCE480}),
   .INIT_79({MAINTENANCE487, MAINTENANCE486, MAINTENANCE485, MAINTENANCE484}),
   .INIT_7A({MAINTENANCE491, MAINTENANCE490, MAINTENANCE489, MAINTENANCE488}),
   .INIT_7B({MAINTENANCE495, MAINTENANCE494, MAINTENANCE493, MAINTENANCE492}),
   .INIT_7C({MAINTENANCE499, MAINTENANCE498, MAINTENANCE497, MAINTENANCE496}),
   .INIT_7D({MAINTENANCE503, MAINTENANCE502, MAINTENANCE501, MAINTENANCE500}),
   .INIT_7E({MAINTENANCE507, MAINTENANCE506, MAINTENANCE505, MAINTENANCE504}),
   .INIT_7F({MAINTENANCE511, MAINTENANCE510, MAINTENANCE509, MAINTENANCE508})
  )
  maintenance_data_inst (
    .DI        (64'h0),
    .DIP       (8'h0),
    .RDADDR    (maint_address),
    .RDCLK     (log_clk),
    .RDEN      (1'b1),
    .REGCE     (1'b1),
    .SSR       (log_rst),
    .WE        (8'h0),
    .WRADDR    (9'h0),
    .WRCLK     (log_clk),
    .WREN      (1'b0),

    .DO        (maint_data_out_d),
    .DOP       (),

    .ECCPARITY (),
    .SBITERR   (),
    .DBITERR   ()
  );
  always @ (posedge log_clk) begin
    maint_data_out  <= maint_data_out_d[61:0];
  end


  // }}} End of Request Generation --------


  // {{{ Response Side Check --------------

  always @ (posedge log_clk) begin
    if (log_rst_q) begin
      maint_autocheck_error <= 1'b0;
    end else if (maint_resp_advance_condition && maint_data_out[36] == READ) begin
      if ((maintr_wdata & data_mask) != (maintr_rdata & data_mask)) begin
        maint_autocheck_error <= 1'b1;
      end else begin
        maint_autocheck_error <= 1'b0;
      end
    end
  end

  always @ (posedge log_clk) begin
    if (log_rst_q) begin
      maint_done <= 1'b0;
    end else if ((instruction_cnt == NUMBER_OF_INSTRUCTIONS) &&
                 (maint_bresp_advance_condition || maint_resp_advance_condition)) begin
      maint_done <= 1'b1;
    end
  end

  // }}} End Response Side Check ----------


endmodule
// {{{ DISCLAIMER OF LIABILITY
// -----------------------------------------------------------------
// (c) Copyright 2010 - 2014 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// }}}

