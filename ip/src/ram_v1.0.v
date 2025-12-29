// RAM module   
// v1.0
//
// v1.0 - Initial release
//

`timescale 1 ns / 1 ps       

module ram 
  # (parameter DSIZE = 32,
     parameter ASIZE = 10,
     parameter MEM_INIT_FILE = "")
(
 clk_i, addrw_i, addrr_i, data_i, we_i, ena_i, 
 data_o
);
 input clk_i;                   // Clock signal
 input [ASIZE-1:0] addrw_i;           // Address for write
 input [ASIZE-1:0] addrr_i;           // Address for read
 input [DSIZE-1:0] data_i;           // Data to be written as key
 input we_i;                    // Write data
 input ena_i;                   // Write enable
 output reg [DSIZE-1:0] data_o;      // Data 
 
 localparam DEPTH = 1<<ASIZE;
 
 // Internal registers and wires 
   (* RAM_STYLE="BLOCK" *) 
 reg [DSIZE-1:0] mem_r [0:DEPTH-1];      



 initial
   begin
     if (MEM_INIT_FILE != "")
       begin
         $readmemh(MEM_INIT_FILE,mem_r);
       end
   end

 always @ (posedge clk_i)
   begin
     if (we_i & ena_i)
       mem_r[addrw_i] <= data_i;
			 
	   data_o <= mem_r[addrr_i];
   end

endmodule