`timescale 1ns/1ps

module tb;

localparam TP = 4;
localparam NUM_LINE = 512;
localparam NUM_PIX = 640;

integer ii,jj,kk;
integer fid1, fid2;  

reg clk = 1'b0;
reg rstn;

always #(TP/2) clk = ~clk;

initial
  begin
    rstn = 1'b0;
    
    #(TP*10) rstn = 1'b1;
  end    

reg axis_tvalid;
reg [7:0] axis_tdata;
reg [7:0] dummy_data;
reg axis_tlast;
reg axis_tkeep;            

wire [7:0] axis_tdata_w;
wire axis_tvalid_w;
wire axis_tkeep_w;
wire axis_tlast_w;

initial
  begin
    fid1 = $fopen("alena_8bit.raw","rb");
    axis_tkeep = 1'b1;
    axis_tlast = 1'b0;
    axis_tvalid = 1'b0;
    
    wait (rstn);
    
    for (ii=0;ii<NUM_LINE;ii++) begin: line_gen
      for (jj=0;jj<NUM_PIX;jj++) begin: pix_gen
        dummy_data = $fgetc(fid1);  // Read zero MSB
        axis_tdata = $fgetc(fid1);  // Read pixel data
        axis_tvalid = 1'b1;
        
        if (jj == NUM_PIX-1) axis_tlast = 1'b1;
        
        repeat (1) @(negedge clk);
      end
      
      axis_tvalid = 1'b0;
      axis_tlast = 1'b0;
      
      repeat (100) @(negedge clk);
    end  
    
//    repeat (1000) @(negedge clk);
    
    $fclose(fid1);               
//    $finish;
  end             
  
initial
  begin
    fid2 = $fopen("alena_8bit.flt","wb");

    wait (flt_UUT.v_fsm == 3'h5);   // V_DONE
    
    repeat (1000) @(posedge clk);

    $fclose(fid2);               
    $finish;
  end       
  
always @ (posedge clk)
  begin
    if (axis_tvalid_w)
      begin
        $fwrite(fid2,"%c",8'h0);
        $fwrite(fid2,"%c",axis_tdata_w);
      end
  end
  
reg axis_tlast_dly;

always @ (posedge clk) axis_tlast_dly <= axis_tlast;

wire axis_tlast_negedge_w = axis_tlast_dly & ~axis_tlast;

integer line_cnt = 0; // For information purpose

always @ (posedge clk)
  begin
    if (axis_tlast_negedge_w) line_cnt <= line_cnt + 1'b1;
  end                          
    
filter flt_UUT(
  .clk_i          (clk),  
  .rstn_i         (rstn),
//
  .axis_tdata_i   (axis_tdata),
  .axis_tvalid_i  (axis_tvalid),
  .axis_tkeep_i   (axis_tkeep),
  .axis_tlast_i   (axis_tlast),
//
  .axis_tdata_o   (axis_tdata_w),
  .axis_tvalid_o  (axis_tvalid_w),
  .axis_tkeep_o   (axis_tkeep_w),
  .axis_tlast_o   (axis_tlast_w)
);     
  
//-------------------temp part of tb-------------------
wire [23:0] coeff3_w = 24'h00_79a7;
wire [23:0] data0_w  = 24'ha9_0000;

wire [47:0] res_w = data0_w * coeff3_w;

//-----------------------------------------------------


endmodule
