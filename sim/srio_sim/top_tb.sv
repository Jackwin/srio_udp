`timescale 1ps/1ps
`define CLK_CYCLE 6400

module top_tb;

logic sys_clkp;
logic sys_clkn;
logic sys_rst;
logic srio_rxn0;
logic srio_rxp0;
logic srio_txn0;
logic srio_txp0;
logic [3:0] led0_primary;
logic [3:0] led0_mirror;

logic mode_1x;
logic port_initialized;
logic link_initialized;
logic clk_lock;

initial begin
	sys_clkp <= 1'b0;
	forever
		#(CLK_CYCLE/2) sys_clkp = ~sys_clkp;
end

always_comb begin
	sys_clkn = ~sys_clkp;
end

initial begin
	sys_rst = 1'b1;
	#68 sys_rst = 1'b0;
end


  srio_example_top_srio_gen2_0
 //// NOTE: uncomment these lines to simulate packet transfer
 // #(
 //    .SIM_ONLY                (SIM_ONLY            ),//(0), // mirror object handles reporting
 //    .VALIDATION_FEATURES     (VALIDATION_FEATURES ),//(1),
 //    .QUICK_STARTUP           (QUICK_STARTUP       ),//(1),
 //    .USE_CHIPSCOPE           (USE_CHIPSCOPE       ),//(0),
 //    .STATISTICS_GATHERING    (STATISTICS_GATHERING) //(1)
 //   )
   srio_example_top_primary
     (.sys_clkp                (sys_clkp),
      .sys_clkn                (sys_clkn),

      .sys_rst                 (sys_rst),

      .srio_rxn0               (srio_rxn0),
      .srio_rxp0               (srio_rxp0),

      .srio_txn0               (srio_txn0),
      .srio_txp0               (srio_txp0),

      .sim_train_en            (1'b1),
      .led0                    (led0_primary)

     );
	 
	  srio_example_top_srio_gen2_0
 //// NOTE: uncomment these lines to simulate packet transfer
 // #(
 //    .SIM_ONLY                (SIM_ONLY            ),//(0), // mirror object handles reporting
 //    .VALIDATION_FEATURES     (VALIDATION_FEATURES ),//(1),
 //    .QUICK_STARTUP           (QUICK_STARTUP       ),//(1),
 //    .USE_CHIPSCOPE           (USE_CHIPSCOPE       ),//(0),
 //    .STATISTICS_GATHERING    (STATISTICS_GATHERING) //(1)
 //   )
   srio_example_top_mirror
     (.sys_clkp                (sys_clkp),
      .sys_clkn                (sys_clkn),

      .sys_rst                 (sys_rst),

      .srio_rxn0               (srio_txn0),
      .srio_rxp0               (srio_txp0),

      .srio_txn0               (srio_rxn0),
      .srio_txp0               (srio_rxp0),

      .sim_train_en            (1'b1),
      .led0                    (led0_mirror)

     );
	 
	always_comb begin
		mode_1x = !led0[0];
		port_initialized = led0[1];
		link_initialized = led0[2];
		clk_lock = led0[3];
	end
	 
	always @(posedge port_initialized) begin
		$display("Port is initialized.");
	end
	
	always @(posedge link_initialized) begin
		$display("Link is initialized.");
	end
	
endmodule
	
		
		
		
		
		
		
		
		
		
		
		