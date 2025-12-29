`timescale 1ns/1ps

module top_wrapper (
  input clk_i,
//
  input [7:0] axis_tdata_i,
  input axis_tvalid_i,
  input axis_tlast_i,
//
  output [7:0] axis_tdata_o,
  output axis_tvalid_o,
  output axis_tlast_o
);             

wire clk1_w;
wire clk_locked_w;

clk_wiz_0 clk_mgmt1 (
  .clk_out1       (clk1_w),  
//
  .locked         (clk_locked_w),
//
  .clk_in1        (clk_i)
);                      

reg sys_rstn;
reg [7:0] sys_rstn_cnt = 8'h0;

always @ (posedge clk1_w)
  begin
    if (~clk_locked_w)
      begin
        sys_rstn <= 1'b0;
        sys_rstn_cnt <= 8'h0;
      end                    
    else
      begin
        if (~sys_rstn_cnt[7]) 
          begin
            sys_rstn_cnt <= sys_rstn_cnt + 1'b1;
            sys_rstn <= 1'b0;
          end
        else sys_rstn <= 1'b1;
      end
  end

filter flt_inst(
  .clk_i          (clk1_w),  
  .rstn_i         (sys_rstn),
//
  .axis_tdata_i   (axis_tdata_i),
  .axis_tvalid_i  (axis_tvalid_i),
  .axis_tkeep_i   (1'b1),
  .axis_tlast_i   (axis_tlast_i),
//
  .axis_tdata_o   (axis_tdata_o),
  .axis_tvalid_o  (axis_tvalid_o),
  .axis_tkeep_o   (),
  .axis_tlast_o   (axis_tlast_o)
);     


endmodule