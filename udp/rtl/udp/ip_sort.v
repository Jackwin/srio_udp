//***************************************************
// This module sorts the ip datastream into TCP or UDP data.
//***************************************************

module ip_sort
  (
   input 	 clk,
   input 	 reset,

   input [31:0]  ip_data_in,
   input 	 ip_data_valid,
   input 	 ip_data_last,

   output [31:0] tcp_data_out,
   output 	 tcp_data_valid,
   output 	 tcp_data_last,

   output [31:0] udp_data_out,
   output 	 udp_data_valid,
   output 	 udp_data_last	 
	
   );
   
   
