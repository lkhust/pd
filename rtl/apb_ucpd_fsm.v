/*
------------------------------------------------------------------------
--
-- File :                       apb_ucpd_data_trans.v
-- Author:                      luo kun
-- Date :                       $Date: 2020/07/12 $
-- Abstract:                    PD main state machine
-- Modification History:
-- Date                 By      Version Change  Description
-- =====================================================================
-- See CVS log
-- =====================================================================
*/

module apb_ucpd_fsm (
  input        ic_clk          , // usbpd clock(HSI16)
  input        ucpd_clk        ,
  input        ic_rst_n        ,
  input        ucpden          ,
  input        tx_hrst         , // Command to send a Tx Hard Reset
  input        transmit_en     , // Command to send a Tx packet
  input        receive_en      ,
  input        eop_ok          ,
  input        bit_clk_red     ,
  input  [9:0] tx_paysize      , // tx Payload size in bytes, include head and TX_DATA
  input        crc_ok          ,
  input        rx_bit_cmplt    ,
  input        pre_rxbit_edg   ,
  input  [1:0] tx_mode         ,
  input  [6:0] tx_status       ,
  input        transwin_en     ,
  input        ifrgap_en       ,
  input        tx_hrst_red     ,
  input        tx_crst_red     ,
  input        rx_pre_cmplt    ,
  input        rx_sop_cmplt    ,
  input        hrst_vld        ,
  input        crst_vld        ,
  input        tx_hrst_flag    ,
  input        tx_crst_flag    ,
  input        hrst_tx_en      ,
  output       bmc_en          ,
  output       tx_sop_cmplt    ,
  output       tx_wait_cmplt   ,
  output       tx_crc_cmplt    ,
  output       tx_data_cmplt   ,
  output       tx_sop_rst_cmplt,
  output       tx_eop_cmplt    ,
  output       tx_msg_disc     ,
  output       tx_hrst_disc    ,
  output       txfifo_ld_en    ,
  output       cc_oen          ,
  output       dec_rxbit_en    ,
  output       txdr_req        ,
  output       rx_pre_en       ,
  output       rx_sop_en       ,
  output       rx_data_en      ,
  output       pre_en          ,
  output       sop_en          ,
  output       data_en         ,
  output       crc_en          ,
  output       eop_en          ,
  output       wait_en         ,
  output       bist_en
);

  // `include "parameter_def.v"


  /*------------------------------------------------------------------------------
  --  state variables for pd tx main FSM
  ------------------------------------------------------------------------------*/
  localparam TX_IDLE = 3'h0;
  localparam TX_PRE  = 3'h1;
  localparam TX_SOP  = 3'h2;
  localparam TX_DATA = 3'h3;
  localparam TX_CRC  = 3'h4;
  localparam TX_EOP  = 3'h5;
  localparam TX_BIST = 3'h6;
  localparam TX_WAIT = 3'h7;

  /*------------------------------------------------------------------------------
  --  state variables for pd rx main FSM
  ------------------------------------------------------------------------------*/
  localparam RX_IDLE = 2'h0;
  localparam RX_PRE  = 2'h1;
  localparam RX_SOP  = 2'h2;
  localparam RX_DATA = 2'h3;


  // ----------------------------------------------------------
  // -- local registers and wires
  // ----------------------------------------------------------
  //registers
  reg [ 2:0] tx_nxt_state      ;
  reg [ 2:0] tx_cur_state      ;
  reg [ 1:0] rx_nxt_state      ;
  reg [ 1:0] rx_cur_state      ;
  reg [ 3:0] one_data_txbit_cnt;
  reg [ 9:0] txbyte_cnt        ;
  reg [15:0] txbit_cnt         ;

  //wires nets
  wire        trans_cmplt   ;
  wire        enc_txbit_en  ;
  wire [12:0] tx_paybit_size;
  // wire        tx_bit5_cmplt ;
  wire        tx_pre_cmplt  ;
  wire        tx_bit10_cmplt;
  wire        tx_und        ;
  wire        hrst_sent     ;

  assign pre_en  = (tx_cur_state == TX_PRE);
  assign sop_en  = (tx_cur_state == TX_SOP);
  assign data_en = (tx_cur_state == TX_DATA);
  assign crc_en  = (tx_cur_state == TX_CRC);
  assign eop_en  = (tx_cur_state == TX_EOP);
  assign bist_en = (tx_cur_state == TX_BIST);
  assign wait_en = (tx_cur_state == TX_WAIT);

  assign rx_pre_en  = (rx_cur_state == RX_PRE);
  assign rx_sop_en  = (rx_cur_state == RX_SOP);
  assign rx_data_en = (rx_cur_state == RX_DATA);

  assign cc_rx_idle = (tx_cur_state == RX_IDLE);

  assign tx_und    = tx_status[6];
  assign hrst_sent = tx_status[5];

  assign tx_paybit_size = tx_paysize-1;
  assign tx_msg_disc    = receive_en & transmit_en & (tx_cur_state == TX_IDLE);
  assign tx_hrst_disc   = tx_hrst_flag & receive_en & transmit_en & (tx_cur_state == TX_IDLE);

  assign tx_pre_cmplt     = pre_en && bit_clk_red && (txbit_cnt == `PRE_BIT_NUM);
  assign tx_sop_cmplt     = sop_en && bit_clk_red && (txbit_cnt == `SOP_BIT_NUM);
  assign tx_data_cmplt    = data_en && tx_bit10_cmplt && (txbyte_cnt == tx_paybit_size);
  assign tx_crc_cmplt     = crc_en  && bit_clk_red && (txbit_cnt == `CRC_BIT_NUM);
  assign tx_eop_cmplt     = eop_en && bit_clk_red && (txbit_cnt == `TX_BIT5_NUM);
  assign tx_wait_cmplt    = wait_en && ifrgap_en;
  assign tx_sop_rst_cmplt = tx_sop_cmplt && (tx_hrst_flag | tx_crst_flag);
  assign tx_bit10_cmplt   = bit_clk_red && (one_data_txbit_cnt == `TX_BIT10_NUM);
  // assign tx_bit5_cmplt    = bit_clk_red && (txbit_cnt == `TX_BIT5_NUM);
  assign txfifo_ld_en     = tx_sop_cmplt || (data_en && tx_bit10_cmplt && ~tx_data_cmplt);
  assign txdr_req         = data_en && (txbyte_cnt < tx_paybit_size); // reqest in vaild time windows

  assign cc_oen           = bmc_en & ucpden;
  assign trans_cmplt      = tx_pre_cmplt | tx_sop_cmplt | tx_data_cmplt | tx_crc_cmplt | tx_eop_cmplt;
  assign bmc_en           = pre_en| sop_en| data_en | crc_en | eop_en | wait_en;
  assign enc_txbit_en     = sop_en | data_en | crc_en | eop_en;
  assign dec_rxbit_en     = rx_sop_en | rx_data_en;
  // ----------------------------------------------------------
  // -- This combinational process calculates FSM the next state
  // -- and generate the outputs in ic_clk domain for tx data
  // ----------------------------------------------------------
  always @ (posedge ic_clk or negedge ic_rst_n) begin
    if (!ic_rst_n)
      tx_cur_state <= TX_IDLE;
    else if(hrst_sent)
      tx_cur_state <= TX_IDLE;
    else
      tx_cur_state <= tx_nxt_state;
  end

  always @(*) begin
    tx_nxt_state = TX_IDLE;
    case (tx_cur_state)
      TX_IDLE :
        begin
          if(ucpden & transwin_en & (transmit_en | tx_hrst | hrst_tx_en))  // SW send TXSEND cmd
            tx_nxt_state = TX_PRE;
          else
            tx_nxt_state = TX_IDLE;
        end

      TX_PRE :
        begin
          if(trans_cmplt) begin
            tx_nxt_state = TX_SOP;
          end
          else
            tx_nxt_state = TX_PRE;
        end

      TX_SOP :
        begin
          if(tx_hrst)
            tx_nxt_state = TX_EOP;
          else if(trans_cmplt) begin
            if(tx_hrst_flag)
              tx_nxt_state = TX_IDLE;
            else if(tx_crst_flag)
              tx_nxt_state = TX_WAIT;
            else if(bist_en)
              tx_nxt_state = TX_BIST;
            else
              tx_nxt_state = TX_DATA;
          end
          else
            tx_nxt_state = TX_SOP;
        end

      TX_DATA :
        begin
          if(tx_hrst | tx_und)
            tx_nxt_state = TX_EOP;
          else if(transmit_en) begin
            if(trans_cmplt)
              tx_nxt_state = TX_CRC;
             else
              tx_nxt_state = TX_DATA;
          end
          else
            tx_nxt_state = TX_DATA;
        end

      TX_CRC :
        begin
          if(tx_hrst)
            tx_nxt_state = TX_EOP;
          else if(trans_cmplt)
            tx_nxt_state = TX_EOP;
          else
            tx_nxt_state = TX_CRC;
        end

      TX_EOP :
        begin
          if(tx_hrst)
            tx_nxt_state = TX_EOP;
          else if(trans_cmplt)
            tx_nxt_state = TX_WAIT;
          else
            tx_nxt_state = TX_EOP;
        end

      TX_BIST :
        begin
          if(tx_hrst)
            tx_nxt_state = TX_IDLE;
          else if(trans_cmplt) // TX_BIST finish
            tx_nxt_state = TX_IDLE;
          else
            tx_nxt_state = TX_BIST;
        end

      TX_WAIT :
        begin
          if(ifrgap_en)
            tx_nxt_state = TX_IDLE;
          else
            tx_nxt_state = TX_WAIT;
        end

      default : ;
    endcase
  end

  /*------------------------------------------------------------------------------
  --  count totole tx bit, according in each fsm stage
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      txbit_cnt <= 16'b0;
    else if(trans_cmplt)
      txbit_cnt <= 16'b0;
    else if(bmc_en & bit_clk_red)
      txbit_cnt <= txbit_cnt+1;
  end

  /*------------------------------------------------------------------------------
  --  count totole tx byte need 10 bits, according in data_en
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      one_data_txbit_cnt <= 4'b0;
    else if(data_en & bit_clk_red) begin
      if(one_data_txbit_cnt == `TX_BIT10_NUM)
        one_data_txbit_cnt <= 4'b0;
      else
        one_data_txbit_cnt <= one_data_txbit_cnt+1;
    end
  end

  /*------------------------------------------------------------------------------
  --  count totole tx byte, according in data_en
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      txbyte_cnt <= 10'b0;
    else if(data_en) begin
      if(txbyte_cnt == tx_paybit_size && tx_bit10_cmplt)
        txbyte_cnt <= 10'b0;
      else if(one_data_txbit_cnt == `TX_BIT10_NUM && bit_clk_red)
        txbyte_cnt <= txbyte_cnt+1;
    end
  end

  // ----------------------------------------------------------
  // -- This combinational process calculates FSM the next state
  // -- and generate the outputs in ucpd_clk domain for rx data
  // ----------------------------------------------------------
  always @ (posedge ucpd_clk or negedge ic_rst_n) begin
    if (!ic_rst_n)
      rx_cur_state <= RX_IDLE;
    else
      rx_cur_state <= rx_nxt_state;
  end

  always @(*) begin
    rx_nxt_state = RX_IDLE;
    case (rx_cur_state)
      RX_IDLE :
        begin
          if(ucpden & receive_en)
            rx_nxt_state = RX_PRE;
          else
            rx_nxt_state = RX_IDLE;
        end

      RX_PRE :
        begin
          if(rx_pre_cmplt)
            rx_nxt_state = RX_SOP;
          else
            rx_nxt_state = RX_PRE;
        end

      RX_SOP :
        begin
          if(eop_ok)
            rx_nxt_state = RX_IDLE;
          else if(rx_sop_cmplt)
            rx_nxt_state = RX_DATA;
          else
            rx_nxt_state = RX_SOP;
        end

      RX_DATA :
        begin
          if(eop_ok | hrst_vld | crst_vld )
            rx_nxt_state = RX_IDLE;
          else
            rx_nxt_state = RX_DATA;
        end

      default : ;

    endcase
  end


endmodule
