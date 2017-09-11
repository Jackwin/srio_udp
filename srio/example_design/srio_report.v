//----------------------------------------------------------------------
//
// SRIO_REPORT
// Description:
// This module collects statistical information about interface
// upon which it is sitting
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

module srio_report #(
  parameter     VERBOSITY = 1,
  parameter     DIRECTION = 1,
  parameter     NAME      = 0) // {0,1} 0 exiting the sRIO core, 1 entering the sRIO core
 (
  input         log_clk,
  input         log_rst,

  input         tvalid,
  input         tready,
  input         tlast,
  input  [63:0] tdata,
  input   [7:0] tkeep,
  input  [31:0] tuser
 );


  // {{{ local parameters -----------------

  // }}} End local parameters -------------


  // {{{ wire declarations ----------------


  // }}} End wire declarations ------------


  // report transmit details when VERBOSITY is 2 or greater
  generate if (DIRECTION == 1 && VERBOSITY > 1) begin : transmit_reporter
    initial begin
      #100000
      wait(!log_rst);
  
      while (1) begin
        wait(tvalid && tready);

            $display(" ");
            if (NAME == 0) begin
            $display("[%t] IREQ Transaction",$time);
            end else if (NAME == 1) begin
            $display("[%t] IRESP Transaction",$time);
            end else if (NAME == 2) begin
            $display("[%t] MSG IRQ Transaction",$time);
            end else if (NAME == 3) begin
            $display("[%t] MSG IRESP Transaction",$time);
            end else if (NAME == 4) begin
            $display("[%t] TRESP Transaction",$time);
            end else if (NAME == 5) begin
            $display("[%t] TREQ Transaction",$time);
            end else if (NAME == 6) begin
            $display("[%t] MSG TRESP Transaction",$time);
            end else if (NAME == 7) begin
            $display("[%t] MSG TREQ Transaction",$time);
            end

            $display("[%t] INFO: Transmitting IO packet", $time);
            $display("[%t]       Instruction #: %h FTYPE: %h TTYPE: %h size-1: %h",
              $time, tdata[63:56], tdata[55:52], tdata[51:48], tdata[43:36]);

        wait(tvalid && tready && tlast);
        @(posedge log_clk);
        #1000;
      end
    end

  // report receiver details when VERBOSITY is 1 or greater
  end else if (DIRECTION == 0 && VERBOSITY > 0) begin : receive_reporter
    initial begin
      #100000
      wait(!log_rst);
  
      while (1) begin
        wait(tvalid && tready);

            $display(" ");
            if (NAME == 0) begin
            $display("[%t] IREQ Receiption",$time);
            end else if (NAME == 1) begin
            $display("[%t] IRESP Receiption",$time);
            end else if (NAME == 2) begin
            $display("[%t] MSGIREQ Receiption",$time);
            end else if (NAME == 3) begin
            $display("[%t] MSGIRESP Receiption",$time);
            end else if (NAME == 4) begin
            $display("[%t] TRESP Receiption",$time);
            end else if (NAME == 5) begin
            $display("[%t] TREQ Receiption",$time);
            end else if (NAME == 6) begin
            $display("[%t] MSG TRESP Receiption",$time);
            end else if (NAME == 7) begin
            $display("[%t] MSG TREQ Receiption",$time);
            end

            $display("[%t] INFO: Receiving IO packet", $time);
            $display("[%t]       srcTID #: %h FTYPE: %h TTYPE: %h size-1: %h",
              $time, tdata[63:56], tdata[55:52], tdata[51:48], tdata[43:36]);

        wait(tvalid && tready && tlast);
        @(posedge log_clk);
        #1000;
      end
    end

  end
  endgenerate


endmodule
// {{{ DISCLAIMER OF LIABILITY
// -----------------------------------------------------------------
// (c) Copyright 2010 Xilinx, Inc. All rights reserved.
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

