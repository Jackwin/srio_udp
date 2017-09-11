`timescale 1ps/1ps
//`define VENDORRAM
module ram
  #(
    parameter addr_width = 10,
    parameter data_width = 64
    )
   (
    input 		    wr_clk,
    input 		    wr_ena,
    input [data_width-1:0]  wr_data,
    input [addr_width-1:0]  wr_addr,
    input [addr_width-1:0]  rd_addr,
    input 		    rd_clk,
    input 		    rd_ena,

    output [data_width-1:0] rd_data
    );
   localparam ram_depth = 2**addr_width;

`ifdef VENDORRAM

          RAMB36E1 #(
          // Address Collision Mode: "PERFORMANCE" or "DELAYED_WRITE"
          .RDADDR_COLLISION_HWCONFIG("DELAYED_WRITE"),
          // Collision check: Values ("ALL", "WARNING_ONLY", "GENERATE_X_ONLY" or "NONE")
          .SIM_COLLISION_CHECK("ALL"),
          // DOA_REG, DOB_REG: Optional output register (0 or 1)
          .DOA_REG(0),
          .DOB_REG(0),
          .EN_ECC_READ("FALSE"),                                                            // Enable ECC decoder,
                                                                                            // FALSE, TRUE
          .EN_ECC_WRITE("FALSE"),                                                           // Enable ECC encoder,
                                                                                            // FALSE, TRUE
          // INIT_A, INIT_B: Initial values on output ports
          .INIT_A(36'h0),
          .INIT_B(36'h0),
          // Initialization File: RAM initialization file
          .INIT_FILE("NONE"),
          // RAM Mode: "SDP" or "TDP"
          .RAM_MODE("SDP"),
          // RAM_EXTENSION_A, RAM_EXTENSION_B: Selects cascade mode ("UPPER", "LOWER", or "NONE")
          .RAM_EXTENSION_A("NONE"),
          .RAM_EXTENSION_B("NONE"),
          // READ_WIDTH_A/B, WRITE_WIDTH_A/B: Read/write width per port
          .READ_WIDTH_A(72),                                                                 // 0-72
          .READ_WIDTH_B(36),                                                                 // 0-36
          .WRITE_WIDTH_A(36),                                                                // 0-36
          .WRITE_WIDTH_B(72),                                                                // 0-72
          // RSTREG_PRIORITY_A, RSTREG_PRIORITY_B: Reset or enable priority ("RSTREG" or "REGCE")
          .RSTREG_PRIORITY_A("RSTREG"),
          .RSTREG_PRIORITY_B("RSTREG"),
          // SRVAL_A, SRVAL_B: Set/reset value for output
          .SRVAL_A(36'h000000000),
          .SRVAL_B(36'h000000000),
          // Simulation Device: Must be set to "7SERIES" for simulation behavior
          .SIM_DEVICE("7SERIES"),
          // WriteMode: Value on output upon a write ("WRITE_FIRST", "READ_FIRST", or "NO_CHANGE")
          .WRITE_MODE_A("WRITE_FIRST"),
          .WRITE_MODE_B("WRITE_FIRST")
       )
       RAMB36E1_inst (
          // Cascade Signals: 1-bit (each) output: BRAM cascade ports (to create 64kx1)
          .CASCADEOUTA(),     // 1-bit output: A port cascade
          .CASCADEOUTB(),     // 1-bit output: B port cascade
          // ECC Signals: 1-bit (each) output: Error Correction Circuitry ports
          .DBITERR(),             // 1-bit output: Double bit error status
          .ECCPARITY(),         // 8-bit output: Generated error correction parity
          .RDADDRECC(),         // 9-bit output: ECC read address
          .SBITERR(),             // 1-bit output: Single bit error status
          // Port A Data: 32-bit (each) output: Port A data
          .DOADO(rd_data[31:0]),                 // 32-bit output: A port data/LSB data
          .DOPADOP(),             // 4-bit output: A port parity/LSB parity
          // Port B Data: 32-bit (each) output: Port B data
          .DOBDO(rd_data[63:32]),                 // 32-bit output: B port data/MSB data
          .DOPBDOP(),             // 4-bit output: B port parity/MSB parity
          // Cascade Signals: 1-bit (each) input: BRAM cascade ports (to create 64kx1)
          .CASCADEINA(),       // 1-bit input: A port cascade
          .CASCADEINB(),       // 1-bit input: B port cascade
          // ECC Signals: 1-bit (each) input: Error Correction Circuitry ports
          .INJECTDBITERR(), // 1-bit input: Inject a double bit error
          .INJECTSBITERR(), // 1-bit input: Inject a single bit error
          // Port A Address/Control Signals: 16-bit (each) input: Port A address and control signals (read port
          // when RAM_MODE="SDP")
          .ADDRARDADDR(rd_addr),     // 16-bit input: A port address/Read address
          .CLKARDCLK(rd_clk),         // 1-bit input: A port clock/Read clock
          .ENARDEN(rd_ena),             // 1-bit input: A port enable/Read enable
          .REGCEAREGCE(1'b0),     // 1-bit input: A port register enable/Register enable
          .RSTRAMARSTRAM(1'b0), // 1-bit input: A port set/reset
          .RSTREGARSTREG(1'b0), // 1-bit input: A port register set/reset
          .WEA(1'b0),                     // 4-bit input: A port write enable
          // Port A Data: 32-bit (each) input: Port A data
          .DIADI(wr_data[31:0]),                 // 32-bit input: A port data/LSB data
          .DIPADIP(),             // 4-bit input: A port parity/LSB parity
          // Port B Address/Control Signals: 16-bit (each) input: Port B address and control signals (write port
          // when RAM_MODE="SDP")
          .ADDRBWRADDR(wr_addr),     // 16-bit input: B port address/Write address
          .CLKBWRCLK(wr_clk),         // 1-bit input: B port clock/Write clock
          .ENBWREN(wr_ena),             // 1-bit input: B port enable/Write enable
          .REGCEB(1'b0),               // 1-bit input: B port register enable
          .RSTRAMB(1'b0),             // 1-bit input: B port set/reset
          .RSTREGB(1'b0),             // 1-bit input: B port register set/reset
          .WEBWE(8'hff),                 // 8-bit input: B port write enable/Write enable
          // Port B Data: 32-bit (each) input: Port B data
          .DIBDI(wr_data[63:32]),                 // 32-bit input: B port data/MSB data
          .DIPBDIP()              // 4-bit input: B port parity/MSB parity
       );

`else
   reg [data_width-1:0] 	ram [0:ram_depth-1];
   always @(posedge wr_clk) begin
      if (wr_ena) ram[wr_addr] <= wr_data;
   end

   assign rd_data = ram[rd_addr];

`endif

   
endmodule // ram



	
   
   
