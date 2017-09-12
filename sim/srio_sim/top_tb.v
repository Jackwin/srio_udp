`timescale 1ps/1ps
`define CLK_CYCLE 6400

module top_tb;

reg sys_clkp;
wire  sys_clkn;
reg sys_rst;
wire  srio_rxn0;
wire srio_rxp0;
wire srio_txn0;
wire srio_txp0;
wire [3:0] led0_primary;
wire [3:0] led0_mirror;

wire mode_1x;
wire port_initialized;
wire link_initialized;
wire clk_lock;
parameter MIRROR = 1;
initial begin
	sys_clkp <= 1'b0;
	forever
		#(`CLK_CYCLE/2) sys_clkp <= ~sys_clkp;
end


assign sys_clkn = ~sys_clkp;


initial begin
	sys_rst <= 1'b1;
	#68000 sys_rst <= 1'b0;
end


  srio_example_top_srio_gen2_0
 //// NOTE: uncomment these lines to simulate packet transfer
  //#(
		
 //    .SIM_ONLY                (SIM_ONLY            ),//(0), // mirror object handles reporting
 //    .VALIDATION_FEATURES     (VALIDATION_FEATURES ),//(1),
 //    .QUICK_STARTUP           (QUICK_STARTUP       ),//(1),
 //    .USE_CHIPSCOPE           (USE_CHIPSCOPE       ),//(0),
 //    .STATISTICS_GATHERING    (STATISTICS_GATHERING) //(1)
 //  )
   srio_example_top_primary
     (.sys_clkp                (sys_clkp),
      .sys_clkn                (sys_clkn),

      .sys_rst_n                 (~sys_rst),

      .srio_rxn0               (srio_rxn0),
      .srio_rxp0               (srio_rxp0),

      .srio_txn0               (srio_txn0),
      .srio_txp0               (srio_txp0),

      //.sim_train_en            (1'b1),
      .led0                    (led0_primary)

     );
	 
	  srio_example_top_srio_gen2_0
 //// NOTE: uncomment these lines to simulate packet transfer
  #(
		.MIRROR (MIRROR)
 //    .SIM_ONLY                (SIM_ONLY            ),//(0), // mirror object handles reporting
 //    .VALIDATION_FEATURES     (VALIDATION_FEATURES ),//(1),
 //    .QUICK_STARTUP           (QUICK_STARTUP       ),//(1),
 //    .USE_CHIPSCOPE           (USE_CHIPSCOPE       ),//(0),
 //    .STATISTICS_GATHERING    (STATISTICS_GATHERING) //(1)
    )
   srio_example_top_mirror
     (.sys_clkp                (sys_clkp),
      .sys_clkn                (sys_clkn),

      .sys_rst_n                 (~sys_rst),

      .srio_rxn0               (srio_txn0),
      .srio_rxp0               (srio_txp0),

      .srio_txn0               (srio_rxn0),
      .srio_txp0               (srio_rxp0),

     // .sim_train_en            (1'b1),
      .led0                    (led0_mirror)

     );
	 
	
	assign	mode_1x = !led0_primary[0];
	assign	port_initialized = led0_primary[1];
	assign	link_initialized = led0_primary[2];
	assign	clk_lock = led0_primary[3];
	 
	always @(posedge port_initialized) begin
		$display("Port is initialized.");
	end
	
	always @(posedge link_initialized) begin
		$display("Link is initialized.");
	end
	
endmodule
	
		
		
		
		
		
		
		
		
		
		
		