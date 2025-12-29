// Pipelined delay v1.1
//
// v1.0 - Initial release
// v1.1 - Added shreg extract as parameter


`timescale 1ns/1ps

module pipeline_dly # (
  parameter  DATA_WIDTH = 32,
  parameter  PIPE_DEPTH = 1,
  parameter  SH_REG_EXTRACT = 0)  // If == 0 shreg_extract = "no" attribute is set
  (
  input clk_i,
  input [DATA_WIDTH-1:0] d_i,
  output [DATA_WIDTH-1:0] d_o
  );

wire [DATA_WIDTH-1:0] tmp_w [0:PIPE_DEPTH];
genvar i;
generate
  if (PIPE_DEPTH != 0) 
    begin: ppl_nzero
      assign tmp_w[0] = d_i;
      assign d_o = tmp_w[PIPE_DEPTH];
      
      for (i=0; i<PIPE_DEPTH; i=i+1)
        begin: ppl_thread
          ppl_blk # (
            .DATA_WH (DATA_WIDTH),
            .SH_REG_EXT (SH_REG_EXTRACT))
            ppl_item (
              .clk_i   (clk_i),
              .data_i  (tmp_w[i]),
              .data_o  (tmp_w[i+1])
            );
        end
    end
  else
    begin
      assign d_o = d_i; 
    end
endgenerate    
  
endmodule

module ppl_blk # (
  parameter DATA_WH = 32,
  parameter SH_REG_EXT = 0)
  (
  input clk_i,
  input [DATA_WH-1:0] data_i,
  output[DATA_WH-1:0] data_o
  );

generate
  if (~SH_REG_EXT)
    begin: shr_gren
      (*shreg_extract = "no", keep="true"*) reg [DATA_WH-1:0] data_ppl;           // For design 
      
      assign data_o = data_ppl;
      always @ (posedge clk_i) data_ppl <= data_i;
    end    
  else
    begin
      reg [DATA_WH-1:0] data_ppl;
      
      assign data_o = data_ppl;
      always @ (posedge clk_i) data_ppl <= data_i;      
    end
endgenerate
  
endmodule
  