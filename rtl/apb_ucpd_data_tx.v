
/*
------------------------------------------------------------------------
--
-- File :                       apb_ucpd_data_tx.v
-- Author:                      luo kun
-- Date :                       $Date: 2020/07/12 $
-- Abstract: This module is used to process SW send data, and trans 4b5b Symbol Encoding,
             finially bmc encode output bit.
-- Modification History:
-- Date                 By      Version Change  Description
-- =====================================================================
-- See CVS log
-- =====================================================================
*/
module apb_ucpd_data_tx (
  input             ic_clk       , // processor clock
  input             ic_rst_n     , // asynchronous reset, active low
  input             tx_hrst      ,
  input             bit_clk_red  ,
  input             transmit_en  ,
  input             tx_sop_cmplt ,
  input             tx_crc_cmplt ,
  input             tx_wait_cmplt,
  input             tx_data_cmplt,
  input             tx_eop_cmplt ,
  input             txdr_req     ,
  input             pre_en       ,
  input             bmc_en       ,
  input             sop_en       ,
  input             data_en      ,
  input             crc_en       ,
  input             eop_en       ,
  input             bist_en      ,
  input             tx_ordset_we ,
  input             txfifo_ld_en ,
  input             txdr_we      ,
  input      [ 1:0] tx_mode      ,
  input             tx_msg_disc  ,
  input             tx_hrst_disc ,
  input      [ 7:0] ic_txdr      ,
  input      [31:0] crc_in       ,
  input      [19:0] tx_ordset    , // consisting of 4 K-codes for sop, from UCPD_TX_ORDSET
  output     [ 6:0] tx_status    ,
  output            tx_hrst_red  ,
  output            tx_crst_red  ,
  output reg        tx_hrst_flag ,
  output reg        tx_crst_flag ,
  output reg        txhrst_clr   ,
  output reg        txsend_clr   ,
  output reg        hrst_tx_en   ,
  output reg        tx_bit
);

  // `include "parameter_def.v"

  // ----------------------------------------------------------
  // -- local registers and wires
  // ----------------------------------------------------------
  //registers
  reg [127:0] pre_shift     ;
  reg [ 39:0] tx_crc_40bits ;
  reg [  9:0] tx_data_10bits;
  reg [ 19:0] sop_shift     ;
  reg [  9:0] data_shift    ;
  reg [ 39:0] crc_shift     ;
  reg [  4:0] eop_shift     ;
  reg         txfifo_full   ;
  reg         txdr_we_d     ;

  //wires nets
  wire tx_und         ;
  wire tx_int_empty   ;
  wire tx_msg_sent    ;
  wire hrst_sent      ;
  wire transmit_en_red;

  assign tx_und       = ~txfifo_full & txfifo_ld_en & data_en;
  assign tx_int_empty = ~txfifo_full & txdr_req & data_en;
  assign tx_msg_abt   = tx_hrst_red & (sop_en | data_en | crc_en);
  assign tx_msg_sent  = tx_wait_cmplt & ~tx_hrst_flag;
  assign hrst_sent    = tx_sop_cmplt & tx_hrst_flag;
  assign tx_crst      = (tx_mode == 2'b01);
  assign tx_bist      = (tx_mode == 2'b10);

  assign tx_status = {tx_und, hrst_sent,tx_hrst_disc,tx_msg_abt,tx_msg_sent,tx_msg_disc,tx_int_empty};

  reg bit_clk_red_d;
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      bit_clk_red_d <= 1'b0;
    else
      bit_clk_red_d <= bit_clk_red;
  end

  reg transmit_en_r;
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      transmit_en_r <= 1'b0;
    else
      transmit_en_r <= transmit_en;
  end

  assign transmit_en_red = ~transmit_en_r & transmit_en;

  /*------------------------------------------------------------------------------
  --  generate tx_hrst, tx_crst, tx_bist positive edge
  ------------------------------------------------------------------------------*/
  reg tx_hrst_r;
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_hrst_r <= 1'b0;
    else
      tx_hrst_r <= tx_hrst;
  end

  assign tx_hrst_red = ~tx_hrst_r & tx_hrst;
  assign tx_hrst_edg = tx_hrst_r ^ tx_hrst;

  reg tx_crst_r;
  always @(posedge ic_clk or posedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_crst_r <= 1'b0;
    else
      tx_crst_r <= tx_crst;
  end
  assign tx_crst_red = ~tx_crst_r & tx_crst;

  reg [1:0] tx_bist_r;
  always @(posedge ic_clk or posedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_bist_r <= 2'b0;
    else
      tx_bist_r <= {tx_bist_r[0], tx_bist};
  end
  assign tx_bist_red = ~tx_bist_r[1] & tx_bist_r[0];
  /*------------------------------------------------------------------------------
  --  according txdr write and txfifo read to generate txfifo's status
  --  0: txfifo empty, 1: txfifo is not empty
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      txfifo_full <= 1'b0;
    else if(txdr_we_d)
      txfifo_full <= 1'b1;
    else if(txfifo_ld_en)
      txfifo_full <= 1'b0;
  end

  /*------------------------------------------------------------------------------
  --  This fifo is used to store tx data from SW writed, data 4b5b Symbol Encoding
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      txdr_we_d <= 1'b0;
    else
      txdr_we_d <= txdr_we;
  end

  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_data_10bits <= 10'b0;
    else if(tx_hrst_red)
      tx_data_10bits <= 10'b0;
    else if(txdr_we_d) begin
      tx_data_10bits[9:5] <= enc_4b5b(ic_txdr[7:4]);
      tx_data_10bits[4:0] <= enc_4b5b(ic_txdr[3:0]);
    end
  end

  /*------------------------------------------------------------------------------
  --  generate last tx bit
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_bit <= 1'b0;
    else if(bit_clk_red_d) begin
      if(pre_en)
        tx_bit <= pre_shift[0];
      else if(sop_en)
        tx_bit <= sop_shift[0];
      else if(data_en)
        tx_bit <= data_shift[0];
      else if(crc_en)
        tx_bit <= crc_shift[0];
      else if(eop_en)
        tx_bit <= eop_shift[0];
    end
  end

  /*------------------------------------------------------------------------------
  --  generate preamble code, bit=1 number is 64, bit=0 number is 64, totle bit is 128
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      pre_shift <= 128'b0;
    else if(transmit_en_red | tx_hrst_red | tx_crst_red | tx_sop_cmplt)
      pre_shift <= {64{2'b10}};
    else if(pre_en & bit_clk_red)
      pre_shift <= {1'b0, pre_shift[127:1]};
  end

  /*------------------------------------------------------------------------------
  --  according tx order set value to shift sop bit
  --  Hard Reset: Preamle RST-1 RST-1 RST-1 RST-2, transmit RST-2 RST-1 RST-1 RST-1
  --  Cable Reset: Preamble(training for receiver) RST-1 Sync-1 RST-1 Sync-3, transmit
  --  Sync-3 RST-1 Sync-1 RST-1
  ------------------------------------------------------------------------------*/
  reg tx_ordset_we_d;
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_ordset_we_d <= 1'b0;
    else
      tx_ordset_we_d <= tx_ordset_we;
  end

  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      sop_shift <= 20'b0;
    else if(tx_hrst_red)
      sop_shift <= {`RST_2,`RST_1,`RST_1,`RST_1};
    else if(tx_crst_red || (pre_en && tx_crst))
      sop_shift <= {`SYNC_3,`RST_1,`SYNC_1,`RST_1};
    else if(tx_ordset_we_d)
      sop_shift <= tx_ordset;
    else if(sop_en & bit_clk_red)
      sop_shift <= {1'b0, sop_shift[19:1]};
  end

  /*------------------------------------------------------------------------------
  --  according encode tx data to shift data bit
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      data_shift <= 10'b0;
    else if(txfifo_ld_en)
      data_shift <= tx_data_10bits;
    else if(data_en & bit_clk_red)
      data_shift <= {1'b0, data_shift[9:1]};
  end

  /*------------------------------------------------------------------------------
  --  according encode tx crc to shift crc bit
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      crc_shift <= 40'b0;
    else if(tx_data_cmplt)
      crc_shift <= tx_crc_40bits;
    else if(crc_en & bit_clk_red)
      crc_shift <= {1'b0, crc_shift[39:1]};
  end

  /*------------------------------------------------------------------------------
  --  according `EOP to shift `EOP bit
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      eop_shift <= 5'b0;
    else if(tx_crc_cmplt | tx_hrst_red)
      eop_shift <= `EOP;
    else if(eop_en & bit_clk_red)
      eop_shift <= {1'b0, eop_shift[4:1]};
  end

  /*------------------------------------------------------------------------------
  --  transform crc data(32bits) 4bits to 5bits
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_crc_40bits <= 40'b0;
    else begin
      tx_crc_40bits[4:0]   <= enc_4b5b(crc_in[ 3: 0]);
      tx_crc_40bits[9:5]   <= enc_4b5b(crc_in[ 7: 4]);
      tx_crc_40bits[14:10] <= enc_4b5b(crc_in[11: 8]);
      tx_crc_40bits[19:15] <= enc_4b5b(crc_in[15:12]);
      tx_crc_40bits[24:20] <= enc_4b5b(crc_in[19:16]);
      tx_crc_40bits[29:25] <= enc_4b5b(crc_in[23:20]);
      tx_crc_40bits[34:30] <= enc_4b5b(crc_in[27:24]);
      tx_crc_40bits[39:35] <= enc_4b5b(crc_in[31:28]);
    end
  end

  /*------------------------------------------------------------------------------
  --  for fsm to generate tx hrst flag tx crst flag ,claer and hrest enable
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_hrst_flag <= 1'b0;
    else if(tx_hrst_red)
      tx_hrst_flag <= 1'b1;
    else if(tx_hrst_flag & tx_sop_cmplt)
      tx_hrst_flag <= 1'b0;
  end

  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_crst_flag <= 1'b0;
    else if(tx_crst_red || (pre_en && tx_crst))
      tx_crst_flag <= 1'b1;
    else if(tx_crst_flag & tx_sop_cmplt)
      tx_crst_flag <= 1'b0;
  end

  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      txhrst_clr <= 1'b0;
    else if((tx_hrst && (pre_en || sop_en || data_en || crc_en)) || tx_hrst_disc)
      txhrst_clr <= 1'b1;
    else
      txhrst_clr <= 1'b0;
  end

  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      txsend_clr <= 1'b0;
    else if((transmit_en & (tx_eop_cmplt | tx_wait_cmplt)) || tx_msg_disc)
      txsend_clr <= 1'b1;
    else
      txsend_clr <= 1'b0;
  end

  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      hrst_tx_en <= 1'b0;
    else if(tx_hrst_flag & tx_eop_cmplt)
      hrst_tx_en <= 1'b1;
    else if(hrst_tx_en & tx_sop_cmplt)
      hrst_tx_en <= 1'b0;
  end

  function [4:0] enc_4b5b (input [3:0] tx_4bits);
    begin
      case (tx_4bits)
        4'b0000 : enc_4b5b = 5'b11110; // 0
        4'b0001 : enc_4b5b = 5'b01001; // 1
        4'b0010 : enc_4b5b = 5'b10100; // 2
        4'b0011 : enc_4b5b = 5'b10101; // 3
        4'b0100 : enc_4b5b = 5'b01010; // 4
        4'b0101 : enc_4b5b = 5'b01011; // 5
        4'b0110 : enc_4b5b = 5'b01110; // 6
        4'b0111 : enc_4b5b = 5'b01111; // 7
        4'b1000 : enc_4b5b = 5'b10010; // 8
        4'b1001 : enc_4b5b = 5'b10011; // 9
        4'b1010 : enc_4b5b = 5'b10110; // A
        4'b1011 : enc_4b5b = 5'b10111; // B
        4'b1100 : enc_4b5b = 5'b11010; // C
        4'b1101 : enc_4b5b = 5'b11011; // D
        4'b1110 : enc_4b5b = 5'b11100; // E
        4'b1111 : enc_4b5b = 5'b11101; // F
      endcase
    end
  endfunction

endmodule
