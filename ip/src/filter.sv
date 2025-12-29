`timescale 1ns/1ps

module filter (
  input clk_i,  
  input rstn_i,
//
  input [7:0] axis_tdata_i,
  input axis_tvalid_i,
  input axis_tkeep_i,
  input axis_tlast_i,
//
  output reg [7:0] axis_tdata_o,
  output reg axis_tvalid_o,
  output reg axis_tkeep_o,
  output reg axis_tlast_o
);             

localparam DSIZE = 8;
localparam ASIZE = 10;   // One line is 640 pixels - nearest ^2 is 1024 (2^10).

genvar i;

// Filter coefficients:
// [0.028087,0.23431,0.475206,0.23431,0.028087]
// In fixed point Q8.16 format:
// [00_0731,00_3BFC,00_79A7,00_3BFC,00_0731]  

localparam COEFF0 = 24'h00_0731;
localparam COEFF1 = 24'h00_3bfc;
localparam COEFF2 = 24'h00_79a7;
localparam COEFF3 = 24'h00_3bfc;
localparam COEFF4 = 24'h00_0731;

reg [7:0] axis_tdata_buf, axis_tdata_buf2;
reg axis_tvalid_buf, axis_tvalid_buf2;
reg axis_tlast_buf,axis_tlast_buf2;

always @ (posedge clk_i) axis_tdata_buf <= axis_tdata_i;
always @ (posedge clk_i) axis_tdata_buf2 <= axis_tdata_buf;

always @ (posedge clk_i) axis_tvalid_buf <= axis_tvalid_i;
always @ (posedge clk_i) axis_tvalid_buf2 <= axis_tvalid_buf;

always @ (posedge clk_i) axis_tlast_buf <= axis_tlast_i;
always @ (posedge clk_i) axis_tlast_buf2 <= axis_tlast_buf;

reg [9:0] addrw,addrr;
reg [7:0] data;
reg [5:0] we;
wire [7:0] data_w [0:5]; 


generate   
  for (i=0;i<6;i++) begin: mem_gen
    ram #(
      .DSIZE (DSIZE),
      .ASIZE (ASIZE),
      .MEM_INIT_FILE ("")
      )
      data_buf
    (
      .clk_i        (clk_i), 
      .addrw_i      (addrw), 
      .addrr_i      (addrr), 
      .data_i       (data), 
      .we_i         (we[i]), 
      .ena_i        (1'b1), 
      .data_o       (data_w[i])
    );
  end
endgenerate

wire axis_tvalid_ppl_w;  
wire axis_tlast_ppl_w;

localparam PIPE_DEPTH = 4;

pipeline_dly #(
  .DATA_WIDTH (1),
  .PIPE_DEPTH (PIPE_DEPTH),
  .SH_REG_EXTRACT (0)
  )  
  tvalid_ppl
  (
  .clk_i      (clk_i),
  .d_i        (axis_tvalid_buf2),
  .d_o        (axis_tvalid_ppl_w)
  ); 
  
pipeline_dly #(
  .DATA_WIDTH (1),
  .PIPE_DEPTH (PIPE_DEPTH),
  .SH_REG_EXTRACT (0)
  )  
  tlast_ppl
  (
  .clk_i      (clk_i),
  .d_i        (axis_tlast_buf2),
  .d_o        (axis_tlast_ppl_w)
  ); 

reg [2:0] we_wr_idx; 

reg axis_tvalid_ppl_dly;

always @ (posedge clk_i) axis_tvalid_ppl_dly <= axis_tvalid_ppl_w;

wire axis_tvalid_ppl_negedge_w = axis_tvalid_ppl_dly & ~axis_tvalid_ppl_w;

always @ (posedge clk_i)
  begin
    if (~rstn_i) we_wr_idx <= 3'h0;
    else if (axis_tvalid_ppl_negedge_w)
      begin
        if (we_wr_idx == 3'h5) we_wr_idx <= 3'h0;
        else we_wr_idx <= we_wr_idx + 1'b1;
      end
  end

reg [7:0] sum_res;

always @ (posedge clk_i)
  begin             
    if (axis_tvalid_ppl_w)
      begin
        we[we_wr_idx] <= 1'b1;
        data <= sum_res;
        addrw <= addrw + 1'b1;
      end    
    else
      begin
        we <= 6'h0;
        addrw <= 10'h3FF;
      end
  end
  
reg we_dly;

wire we_or_w = |we;

always @ (posedge clk_i) we_dly <= we_or_w;

wire we_negedge_w = we_dly & ~we_or_w;

//-------------------Horizontal filter FSM---------------------
reg [1:0] h_fsm;
localparam [1:0]
  H_IDLE         = 2'h0,
  H_START        = 2'h1,
  H_LINE_DONE    = 2'h2
  ;
  
reg [23:0] h_data [0:4];

always @ (posedge clk_i)
  begin
    if (h_fsm == H_IDLE)
      begin
        h_data[0] <= {axis_tdata_buf,16'h0};   // Зеркалирование в начале строки
        h_data[1] <= {axis_tdata_buf2,16'h0};
        h_data[2] <= {axis_tdata_buf2,16'h0};
        h_data[3] <= {axis_tdata_buf,16'h0};
        h_data[4] <= {axis_tdata_i,16'h0};
      end 
    else
      begin
        h_data[0] <= h_data[1];
        h_data[1] <= h_data[2];
        h_data[2] <= h_data[3];
        h_data[3] <= h_data[4];
        
        if (axis_tvalid_buf & axis_tlast_buf) h_data[4] <= h_data[3];  // Зеркалирование в конце строки
        else if (axis_tvalid_buf2 & axis_tlast_buf2) h_data[4] <= h_data[1];
        else h_data[4] <= {axis_tdata_i,16'h0};
      end
  end
  
reg [47:0] mult [0:4];

always @ (posedge clk_i) mult[0] <= h_data[0] * COEFF0;
always @ (posedge clk_i) mult[1] <= h_data[1] * COEFF1;
always @ (posedge clk_i) mult[2] <= h_data[2] * COEFF2;
always @ (posedge clk_i) mult[3] <= h_data[3] * COEFF3;
always @ (posedge clk_i) mult[4] <= h_data[4] * COEFF4; 

reg [7:0] sum [0:1];

always @ (posedge clk_i) sum[0] <= mult[0][39:32] + mult[1][39:32] + mult[2][39:32];
always @ (posedge clk_i) sum[1] <= mult[3][39:32] + mult[4][39:32];


always @ (posedge clk_i) sum_res <= sum[0] + sum[1];

reg [9:0] h_line_cnt;

always @ (posedge clk_i)
  begin
    if (~rstn_i)
      begin             
        h_line_cnt <= 10'h0;
        h_fsm <= H_IDLE;
      end
    else
      begin
        case (h_fsm)
          H_IDLE:
            begin
              if (axis_tvalid_buf2) h_fsm <= H_START;
            end
          H_START:
            begin
              if (we_negedge_w) h_fsm <= H_LINE_DONE;
            end                                       
          H_LINE_DONE:
            begin             
              h_fsm <= H_IDLE;
              
              if (h_line_cnt == 10'd512) h_line_cnt <= 10'd0;
              else h_line_cnt <= h_line_cnt + 1'b1;
            end
        endcase
      end
  end
//-------------------------------------------------------------  
//
//--------------------Vertical filter FSM----------------------
reg [2:0] v_fsm;
localparam [2:0]
  V_IDLE       = 3'h0,
  V_START      = 3'h1,
  V_LINE       = 3'h2,
  V_LINE_DONE  = 3'h3,
  V_LAST_LINE  = 3'h4,
  V_DONE       = 3'h5
  ; 
  
reg [23:0] v_data [0:4]; 

reg [9:0] v_line_cnt;          
reg [2:0] data0_idx;
reg [2:0] data1_idx;
reg [2:0] data2_idx;
reg [2:0] data3_idx;
reg [2:0] data4_idx;

always @ (posedge clk_i) v_data[0] <= {data_w[data0_idx],16'h0};
always @ (posedge clk_i) v_data[1] <= {data_w[data1_idx],16'h0};
always @ (posedge clk_i) v_data[2] <= {data_w[data2_idx],16'h0};
always @ (posedge clk_i) v_data[3] <= {data_w[data3_idx],16'h0};
always @ (posedge clk_i) v_data[4] <= {data_w[data4_idx],16'h0};

reg [47:0] v_mult [0:4];

always @ (posedge clk_i) v_mult[0] <= v_data[0] * COEFF0;
always @ (posedge clk_i) v_mult[1] <= v_data[1] * COEFF1;
always @ (posedge clk_i) v_mult[2] <= v_data[2] * COEFF2;
always @ (posedge clk_i) v_mult[3] <= v_data[3] * COEFF3;
always @ (posedge clk_i) v_mult[4] <= v_data[4] * COEFF4;

reg [7:0] v_sum [0:1];

always @ (posedge clk_i) v_sum[0] <= v_mult[0][39:32] + v_mult[1][39:32] + v_mult[2][39:32];
always @ (posedge clk_i) v_sum[1] <= v_mult[3][39:32] + v_mult[4][39:32];

reg [7:0] v_sum_res;

always @ (posedge clk_i) v_sum_res <= v_sum[0] + v_sum[1];

reg v_line_flip;

always @ (posedge clk_i)
  begin
    if (v_fsm == V_LINE) v_line_flip <= 1'b1;
    else v_line_flip <= 1'b0;
  end 
  
reg v_start_out;
reg v_last_line;
reg [2:0] v_last_line_cnt;

reg [7:0] v_last_line_dly_cnt; 
reg v_axis_tvalid;
reg v_axis_tlast;

wire v_axis_tvalid_ppl_w;
wire v_axis_tlast_ppl_w;


pipeline_dly #(
  .DATA_WIDTH (1),
  .PIPE_DEPTH (PIPE_DEPTH),
  .SH_REG_EXTRACT (0)
  )  
  v_tvalid_ppl
  (
  .clk_i      (clk_i),
  .d_i        (v_axis_tvalid),
  .d_o        (v_axis_tvalid_ppl_w)
  ); 
  
pipeline_dly #(
  .DATA_WIDTH (1),
  .PIPE_DEPTH (PIPE_DEPTH),
  .SH_REG_EXTRACT (0)
  )  
  v_tlast_ppl
  (
  .clk_i      (clk_i),
  .d_i        (v_axis_tlast),
  .d_o        (v_axis_tlast_ppl_w)
  ); 

reg v_axis_tvalid_ppl_dly;

always @ (posedge clk_i) v_axis_tvalid_ppl_dly <= v_axis_tvalid_ppl_w;

wire v_axis_tvalid_ppl_negedge_w = v_axis_tvalid_ppl_dly & ~v_axis_tvalid_ppl_w;


always @ (posedge clk_i)
  begin
    if (v_fsm == V_LAST_LINE) v_last_line_dly_cnt <= v_last_line_dly_cnt + 1'b1;
    else v_last_line_dly_cnt <= 8'h0;
  end
  
always @ (posedge clk_i)
  begin
    if (~rstn_i)
      begin     
        v_start_out <= 1'b0;
        v_fsm <= V_IDLE;
      end
    else
      begin
        case (v_fsm)
          V_IDLE: 
            begin 
              addrr <= 10'h0;
              v_line_cnt <= 10'd0;
              v_last_line_cnt <= 3'h0;
              v_last_line <= 1'b0;
              v_axis_tvalid <= 1'b0;
              v_axis_tlast <= 1'b0;
              
              data0_idx <= 3'd2;       // Зеркалирование от элемента 0
              data1_idx <= 3'd1;
              data2_idx <= 3'd0;
              data3_idx <= 3'd1;
              data4_idx <= 3'd2;
              
              if (h_line_cnt == 10'd3) 
                begin                  
                  v_start_out <= 1'b1;
                  v_fsm <= V_START;
                end
              else v_start_out <= 1'b0;
            end
          V_START:
            begin 
              if (v_last_line)
                begin
                  if (addrr != 10'd640) 
                    begin
                      addrr <= addrr + 1'b1;
                      v_axis_tvalid <= 1'b1;
                      
                      if (addrr == 10'd639) v_axis_tlast <= 1'b1;
                    end
				          else 
                    begin
                      v_axis_tvalid <= 1'b0;
                      v_axis_tlast <= 1'b0;
                      v_fsm <= V_LINE;
                    end
                end
              else
                begin
                  if (axis_tvalid_buf) addrr <= addrr + 1'b1;
                  if (axis_tlast_buf) v_fsm <= V_LINE;
                end
            end     
          V_LINE:
            begin
              if (~v_line_flip) v_line_cnt <= v_line_cnt + 1'b1;
              else
                begin
                  if (v_line_cnt == 10'd1)
                    begin
                      data0_idx <= 3'd1;    // Зеркалирование от элемента 1
                      data1_idx <= 3'd0;
                      data2_idx <= 3'd1;
                      data3_idx <= 3'd2;
                      data4_idx <= 3'd3;
                    end        
                  else if (v_line_cnt == 10'd2)  // Начало фильтрации без зеркалирования
                    begin
                      data0_idx <= 3'd0;
                      data1_idx <= 3'd1;
                      data2_idx <= 3'd2;
                      data3_idx <= 3'd3;
                      data4_idx <= 3'd4;
                    end      
                  else
                    begin
                      if (data0_idx == 3'd5) data0_idx <= 3'd0;
                      else data0_idx <= data0_idx + 1'b1;
                      
                      if (data1_idx == 3'd5) data1_idx <= 3'd0;
                      else data1_idx <= data1_idx + 1'b1;
                      
                      if (data2_idx == 3'd5) data2_idx <= 3'd0;
                      else data2_idx <= data2_idx + 1'b1;
                      
                      if (data3_idx == 3'd5) data3_idx <= 3'd0;
                      else data3_idx <= data3_idx + 1'b1;
                      
                      if (data4_idx == 3'd5) data4_idx <= 3'd0;
                      else data4_idx <= data4_idx + 1'b1;                      
                    end
                    
                  if (axis_tvalid_ppl_negedge_w & ~v_last_line) v_fsm <= V_LINE_DONE;
                  else if (v_axis_tvalid_ppl_negedge_w & v_last_line) v_fsm <= V_LAST_LINE;   
                end    
            end
          V_LINE_DONE:
            begin
              addrr <= 10'h0;
              
              if (v_line_cnt == 10'd509) 
                begin
                  v_last_line <= 1'b1;
                  v_fsm <= V_LAST_LINE;
                end
              else v_fsm <= V_START; 
            end
          V_LAST_LINE:
            begin  
              addrr <= 10'h0;
              
              if (v_last_line_dly_cnt == 8'h0) v_last_line_cnt <= v_last_line_cnt + 1'b1;
              if (v_last_line_dly_cnt == 8'd100)
                begin
                  if (v_last_line_cnt == 3'h4) v_fsm <= V_DONE;
                  else v_fsm <= V_START;
                end
            end      
          V_DONE:
            begin  
              v_start_out <= 1'b0;
              v_fsm <= V_IDLE;
            end
        endcase
      end
  end
//-------------------------------------------------------------
//
//-------------------Output data writer------------------------  
reg [1:0] dw_fsm;
localparam [1:0]
  DW_IDLE      = 1'h0,
  DW_DATA      = 1'h1,
  DW_LAST      = 2'h2
  ;
  
always @ (posedge clk_i) axis_tkeep_o <= 1'b1;
always @ (posedge clk_i) axis_tdata_o <= v_sum_res;
always @ (posedge clk_i)
  begin
    if (~rstn_i)
      begin
        axis_tvalid_o <= 1'b0;
        axis_tlast_o <= 1'b0;
        dw_fsm <= DW_IDLE;
      end
    else
      begin
        case (dw_fsm)
          DW_IDLE:
            begin
              if (v_start_out) dw_fsm <= DW_DATA; 
            end
          DW_DATA:
            begin
              axis_tvalid_o <= axis_tvalid_ppl_w;
              axis_tlast_o <= axis_tlast_ppl_w;
              
              if (v_last_line) dw_fsm <= DW_LAST;
            end 
          DW_LAST:
            begin
              axis_tvalid_o <= v_axis_tvalid_ppl_w;
              axis_tlast_o <= v_axis_tlast_ppl_w; 
              
              if (v_fsm == V_DONE) dw_fsm <= DW_IDLE;
            end
        endcase
      end
  end
//-------------------------------------------------------------

endmodule