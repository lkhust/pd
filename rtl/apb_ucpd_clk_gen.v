
/*
------------------------------------------------------------------------
--
-- File :                       apb_ucpd_clk_gen.v
-- Author:                      luo kun
-- Date :                       $Date: 2020/07/12 $
// Abstract: This module is used to calculate the required timing and
//           to create the HALF BIT clock when configured as MASTER mode.
-- Modification History:
-- Date                 By      Version Change  Description
-- =====================================================================
-- See CVS log
-- =====================================================================
*/
module apb_ucpd_clk_gen (
  input            ic_clk          , // processor clock
  input            ic_rst_n        , // asynchronous reset, active low
  input            tx_eop_cmplt    ,
  input            tx_sop_rst_cmplt,
  input            transmit_en     ,
  input            bmc_en          ,
  input            wait_en         ,
  input      [4:0] transwin        , // use half bit clock to achieve a legal tTransitionWindow
  input      [4:0] ifrgap          , // Interframe gap
  input      [2:0] psc_usbpdclk    , // Pre-scaler for UCPD_CLK
  input      [5:0] hbitclkdiv      , // Clock divider values to generate a half-bit clock
  output           bit_clk_red     ,
  output           hbit_clk_red    ,
  output           ucpd_clk_red    ,
  output           ucpd_clk        ,
  output           bypass_prescaler,
  output reg       transwin_en     ,
  output reg       ifrgap_en
);

  // ----------------------------------------------------------
  // -- local registers and wires
  // ----------------------------------------------------------
  //registers
  reg [6:0] pre_scaler_cnt;
  reg [6:0] pre_scaler_div;
  reg [5:0] hbit_clk_cnt  ;
  reg [4:0] ifrgap_cnt    ;
  reg [4:0] transwin_cnt  ;
  reg       pre_scaler_clk;
  reg       bit_clk       ;
  reg       bit_clk_r     ;
  reg       hbit_clk_r    ;
  reg       ucpd_clk_r    ;
  reg       transmit_en_d;

  //wires
  wire       hbit_clk_a       ; // half-bit clock
  wire       hbit_clk         ;
  wire       hbit_clk_sync    ;
  wire       hbit_clk_out     ;
  wire [2:0] pre_scaler       ;
  wire [6:0] hbit_div         ;
  wire       bypass_hbitclkdiv;
  wire       transmit_en_edg  ;

  assign hbit_div          = hbitclkdiv+1;
  assign pre_scaler        = psc_usbpdclk;
  assign bypass_prescaler  = (pre_scaler == 3'b0);

  assign bit_clk_red  = ~bit_clk_r & bit_clk;
  assign hbit_clk_red = ~hbit_clk_r & hbit_clk_sync;
  assign ucpd_clk_red = ~ucpd_clk_r & ucpd_clk;
  assign transmit_en_edg = transmit_en_d ^ transmit_en;

  always @(*) begin
    pre_scaler_div = 7'h0;
    case (pre_scaler)
      3'd1 : pre_scaler_div = 7'h1;  // divide by 2
      3'd2 : pre_scaler_div = 7'h2;  // divide by 4
      3'd3 : pre_scaler_div = 7'h4;  // divide by 8
      3'd4 : pre_scaler_div = 7'h8;  // divide by 16
      3'd5 : pre_scaler_div = 7'h10; // divide by 32
      3'd6 : pre_scaler_div = 7'h20; // divide by 64
      3'd7 : pre_scaler_div = 7'h40; // divide by 128
    endcase
  end

  // PSC_USBPDCLK[2:0] = 0x0: Bypass pre-scaling / divide by 1
  assign ucpd_clk = (pre_scaler == 3'b0) ? ic_clk : pre_scaler_clk;

  // HBITCLKDIV[5:0] = 0x0: Divide by 1 to produce HBITCLK
  assign hbit_clk = (hbitclkdiv == 6'b0) ? ucpd_clk : hbit_clk_out;
  // assign hbit_clk_sync = transmit_en_d ? hbit_clk : 1'b0;
  assign hbit_clk_sync = hbit_clk;

  // ----------------------------------------------------------
  // -- Synchronization registers
  // -- transmit_en_red from ic_clk domain Synchroniz to hbit_clk domain
  // ----------------------------------------------------------

  apb_ucpd_clk_div u_hbit_clk (
    .clk_in (ucpd_clk    ),
    .rst_n  (ic_rst_n    ),
    .divisor(hbit_div    ),
    .clk_out(hbit_clk_out)
  );

  /*------------------------------------------------------------------------------
  --  normal package eop and hard_rest or cable reset end at sop, need interframe
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(ic_rst_n == 1'b0) begin
      ifrgap_cnt <= 5'b0;
      ifrgap_en  <= 1'b0;
    end
    else begin
      if(tx_eop_cmplt || tx_sop_rst_cmplt) begin
        ifrgap_cnt <= 5'b0;
        ifrgap_en  <= 1'b0;
      end
      else if((ucpd_clk_red || bypass_prescaler) && wait_en) begin
        if(ifrgap_cnt < ifrgap) begin
          ifrgap_cnt <= ifrgap_cnt+1;
          ifrgap_en  <= 1'b0;
        end
        else begin
          ifrgap_cnt <= 5'b0;
          ifrgap_en  <= 1'b1;
        end
      end
      else
        ifrgap_en  <= 1'b0;
    end
  end

  always @(posedge hbit_clk_sync or negedge ic_rst_n) begin
    if(ic_rst_n == 1'b0) begin
      transwin_cnt <= 5'b0;
      transwin_en  <= 1'b0;
    end
    else begin
      if(transmit_en_edg) begin
        transwin_cnt <= 5'b0;
        transwin_en  <= 1'b0;
      end
      else if(~bmc_en && ~wait_en) begin
        if(transwin_cnt <= transwin) begin
          transwin_cnt <= transwin_cnt+1;
          transwin_en  <= 1'b0;
        end
        else begin
          transwin_cnt <= 5'b0;
          transwin_en  <= 1'b1;
        end
      end
      else
        transwin_en  <= 1'b0;
    end
  end

  /*------------------------------------------------------------------------------
  --  generate tx bit clk by half bit clk div 2
  ------------------------------------------------------------------------------*/
  always @(posedge hbit_clk_sync or negedge ic_rst_n) begin
    if(~ic_rst_n)
      bit_clk <= 1'b0;
    else
      bit_clk <= ~bit_clk;
  end

  always @(posedge hbit_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      transmit_en_d <= 1'b0;
    else
      transmit_en_d <= transmit_en;
  end

  /*------------------------------------------------------------------------------
  --  generate Clock division by PSC_USBPDCLK[2:0] bits
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(ic_rst_n == 1'b0) begin
      pre_scaler_cnt <= 7'b0;
      pre_scaler_clk <= 1'b0;
    end
    else if(pre_scaler_div > 0)begin
      if(pre_scaler_cnt == 64)
        pre_scaler_cnt <= 7'b0;
      else if(pre_scaler_cnt < pre_scaler_div-1) begin
        pre_scaler_cnt <= pre_scaler_cnt+1;
      end
      else begin
        pre_scaler_cnt <= 7'b0;
        pre_scaler_clk <= ~pre_scaler_clk;
      end
    end
    else
      pre_scaler_cnt <= 7'b0;
  end

  /*------------------------------------------------------------------------------
  --  generate clk delay for get its postive edge
  ------------------------------------------------------------------------------*/
  always @ (posedge ic_clk or negedge ic_rst_n) begin
    if (~ic_rst_n) begin
      ucpd_clk_r <= 1'b0;
      hbit_clk_r <= 1'b0;
      bit_clk_r  <= 1'b0;
    end
    else begin
      ucpd_clk_r <= ucpd_clk;
      hbit_clk_r <= hbit_clk_sync;
      bit_clk_r  <= bit_clk;
    end
  end

endmodule

  /*------------------------------------------------------------------------------
  --  The modue use to switch clk without glitch
  ------------------------------------------------------------------------------*/
  // module clk_switch (
  //   input  clk_a  , // Clock
  //   input  clk_b  ,
  //   input  select ,
  //   output out_clk
  // );
  //   reg  q1,q2,q3,q4;
  //   wire or_one,or_two,or_three,or_four;

  //   always @(posedge clk_a) begin
  //     if(clk_a == 1'b1) begin
  //       q1 <= q4;
  //       q3 <= or_one;
  //     end
  //   end

  //   always @(posedge clk_b) begin
  //     if(clk_b == 1'b1) begin
  //       q2 <= q3;
  //       q4 <= or_two;
  //     end
  //   end

  //   assign or_one   = (!q1) | (!select);
  //   assign or_two   = (!q2) | (select);
  //   assign or_three = (q3) | (clk_a);
  //   assign or_four  = (q4) | (clk_b);
  //   assign out_clk  = or_three & or_four;
  // endmodule


