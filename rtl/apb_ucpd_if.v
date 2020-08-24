
// -------------------------------------------------------------------
// -------------------------------------------------------------------
// File :                       apb_ucpd_if.v
// Author:                      luo kun
// Date :                       $Date: 2020/07/12 $
//
//
// Abstract:  Register address offset macros
//            All registers are on 32-bit boundaries
//
// -------------------------------------------------------------------


`define IC_CFG1_OS        8'h00
`define IC_CFG2_OS        8'h04
// address 8'h08 is Reserved
`define IC_CR_OS          8'h0c
`define IC_IMR_OS         8'h10
`define IC_SR_OS          8'h14
`define IC_ICR_OS         8'h18
`define IC_TX_ORDSET_OS   8'h1c
`define IC_TX_PAYSZ_OS    8'h20
`define IC_TXDR_OS        8'h24
`define IC_RX_ORDSET_OS   8'h28
`define IC_RX_PAYSZ_OS    8'h2c
`define IC_RXDR_OS        8'h30
`define IC_RX_ORDEXT1_OS  8'h34
`define IC_RX_ORDEXT2_OS  8'h38

module apb_ucpd_if (
  input             pclk        , // APB clock
  input             presetn     , // APB async reset
  input             wr_en       , // write enable
  input             rd_en       , // read enable
  input      [ 5:0] reg_addr    , // register address offset
  input      [31:0] ipwdata     , // internal APB write data
  input             txhrst_clr  ,
  input             txsend_clr  ,
  input             frs_evt     ,
  input      [ 6:0] tx_status   ,
  input      [ 5:0] rx_status   ,
  input      [ 6:0] rx_ordset   ,
  input      [ 9:0] rx_byte_cnt ,
  input      [ 7:0] rx_byte     ,
  input             hrst_vld    ,
  input      [ 2:0] cc1_compout , // SR.17:16  TYPEC_VSTATE_CC1
  input      [ 2:0] cc2_compout , // SR.19:18  TYPEC_VSTATE_CC2
  output     [ 1:0] phy_en      , // CR.11:10 CCENABLE
  output            set_c500    , // CR.8:7 ANASUBMODE
  output            set_c1500   , // CR.8:7 ANASUBMODE
  output            set_c3000   , // CR.8:7 ANASUBMODE
  output            set_pd      , // CR.9 ANAMODE 1
  output            source_en   , // CR.9 ANAMODE 0
  output            phy_rx_en   , // CR.5 PHYRXEN
  output            cc1_det_en  , // CR.20 CC1TCDIS
  output            cc2_det_en  , // CR.21 CC2TCDIS
  output            phy_cc1_com , // CR.6 PHYCCSEL 0
  output            phy_cc2_com , // CR.6 PHYCCSEL 1
  output            ucpden      , // USB Power Delivery Block Enable
  output     [ 4:0] transwin    , // use half bit clock to achieve a legal tTransitionWindow
  output     [ 4:0] ifrgap      , // Interframe gap
  output     [ 5:0] hbitclkdiv  , // Clock divider values is used to generate a half-bit clock
  output     [ 2:0] psc_usbpdclk, // Pre-scaler for UCPD_CLK
  output     [ 8:0] rx_ordset_en,
  output            tx_hrst     ,
  output            rxdr_rd     ,
  output            transmit_en ,
  output     [ 1:0] tx_mode     ,
  output            ucpd_intr   ,
  output            tx_ordset_we,
  output     [ 9:0] tx_paysize  ,
  output            txdr_we     ,
  output     [ 1:0] rxfilte     ,
  output     [19:0] tx_ordset   ,
  output reg [ 7:0] ic_txdr     ,
  output reg [31:0] iprdata       // internal APB read data
);
  // internal registers
  reg [31:0] ic_cfg1;
  reg [31:0] ic_cfg2;
  reg [31:0] ic_cr;
  reg [31:0] ic_imr;
  reg [31:0] ic_icr;
  reg [31:0] ic_sr;
  reg [31:0] ic_tx_ordset;
  reg [31:0] ic_tx_paysz;
  reg [31:0] ic_rx_ordext1;
  reg [31:0] ic_rx_ordext2;
  reg      [ 1:0] vstate_cc1;
  reg      [ 1:0] vstate_cc2;

  // internal wires
  wire [31:0] ic_cfg1_s         ;
  wire [31:0] ic_cfg2_s         ;
  wire [31:0] ic_cr_s           ;
  wire [31:0] ic_imr_s          ;
  wire [31:0] ic_sr_s           ;
  wire [31:0] ic_tx_paysz_s     ;
  wire [31:0] ic_txdr_s         ;
  wire [31:0] ic_rx_ordset_s    ;
  wire [31:0] ic_rx_paysz_s     ;
  wire [31:0] ic_rxdr_s         ;
  wire [31:0] ic_rx_ordext1_s   ;
  wire [31:0] ic_rx_ordext2_s   ;
  wire [ 2:0] evt_intr_en       ;
  wire        ic_cfg1_en        ;
  wire        ic_cfg2_en        ;
  wire        ic_cr_en          ;
  wire        ic_imr_en         ;
  wire        ic_sr_en          ;
  wire        ic_icr_en         ;
  wire        ic_tx_ordset_en   ;
  wire        ic_tx_paysz_en    ;
  wire        ic_txdr_en        ;
  wire        ic_rx_ordset_en   ;
  wire        ic_rx_paysz_en    ;
  wire        ic_rxdr_en        ;
  wire        ic_rx_ordext1_en  ;
  wire        ic_rx_ordext2_en  ;
  wire        ic_cfg1_we        ;
  wire        ic_cfg2_we        ;
  wire        ic_cr_we          ;
  wire        ic_imr_we         ;
  wire        ic_icr_we         ;
  wire        ic_tx_ordset_we   ;
  wire        ic_tx_paysz_we    ;
  wire        ic_txdr_we        ;
  wire        ic_rx_ordext1_we  ;
  wire        ic_rx_ordext2_we  ;
  wire [ 6:0] tx_status_sync_red;
  wire [ 5:0] rx_status_sync_red;
  wire [ 6:0] tx_status_sync    ;
  wire [ 5:0] rx_status_sync    ;
  wire [ 1:0] vstate_cc1_sync   ;
  wire [ 1:0] vstate_cc2_sync   ;
  wire        typec_evt1_red    ;
  wire        typec_evt2_red    ;
  wire        frs_evt_red       ;
  wire        hard_rst          ;

  assign hard_rst       = tx_status[5];
  assign ic_rx_ordset_s = {{25{1'b0}}, rx_ordset};
  assign ic_rx_paysz_s  = {{22{1'b0}}, rx_byte_cnt};
  assign ic_rxdr_s      = {{24{1'b0}}, rx_byte};

  assign ucpd_intr    = |(ic_imr & ic_sr);
  assign txdr_we      = (ic_txdr_we == 1'b1 && ucpden);
  assign tx_ordset_we = (ic_tx_ordset_we == 1'b1 && ucpden);
  assign tx_ordset    = ic_tx_ordset[19:0];
  assign tx_paysize   = ic_tx_paysz[9:0];
  assign rxfilte      = ic_cfg2[1:0];
  assign transmit_en  = ic_cr[2];



  /*------------------------------------------------------------------------------
  --  Address decoder
  --  Decodes the register address offset input(reg_addr)
  --  to produce enable (select) signals for each of the
  --  SW-registers in the macrocell
  ------------------------------------------------------------------------------*/
  assign ic_cfg1_en       = {2'b00, reg_addr} == (`IC_CFG1_OS       >> 2);
  assign ic_cfg2_en       = {2'b00, reg_addr} == (`IC_CFG2_OS       >> 2);
  assign ic_cr_en         = {2'b00, reg_addr} == (`IC_CR_OS         >> 2);
  assign ic_imr_en        = {2'b00, reg_addr} == (`IC_IMR_OS        >> 2);
  assign ic_sr_en         = {2'b00, reg_addr} == (`IC_SR_OS         >> 2);
  assign ic_icr_en        = {2'b00, reg_addr} == (`IC_ICR_OS        >> 2);
  assign ic_tx_ordset_en  = {2'b00, reg_addr} == (`IC_TX_ORDSET_OS  >> 2);
  assign ic_tx_paysz_en   = {2'b00, reg_addr} == (`IC_TX_PAYSZ_OS   >> 2);
  assign ic_txdr_en       = {2'b00, reg_addr} == (`IC_TXDR_OS       >> 2);
  assign ic_rx_ordset_en  = {2'b00, reg_addr} == (`IC_RX_ORDSET_OS  >> 2);
  assign ic_rx_paysz_en   = {2'b00, reg_addr} == (`IC_RX_PAYSZ_OS   >> 2);
  assign ic_rxdr_en       = {2'b00, reg_addr} == (`IC_RXDR_OS       >> 2);
  assign ic_rx_ordext1_en = {2'b00, reg_addr} == (`IC_RX_ORDEXT1_OS >> 2);
  assign ic_rx_ordext2_en = {2'b00, reg_addr} == (`IC_RX_ORDEXT2_OS >> 2);

  /*------------------------------------------------------------------------------
  --   Write enable signals for writeable SW-registers.
  --   rw registers include UCPD_CFG1, UCPD_CFG2, UCPD_CR, UCPD_IMR, UCPD_TX_ORDSET
                            UCPD_TX_PAYSZ, UCPD_TXDR, UCPD_RX_ORDEXT1, UCPD_RX_ORDEXT2
  --   ow registers include UCPD_ICR
  ------------------------------------------------------------------------------*/
  assign ic_cfg1_we       = ic_cfg1_en       & wr_en;
  assign ic_cfg2_we       = ic_cfg2_en       & wr_en;
  assign ic_cr_we         = ic_cr_en         & wr_en;
  assign ic_imr_we        = ic_imr_en        & wr_en;
  assign ic_icr_we        = ic_icr_en        & wr_en;
  assign ic_tx_ordset_we  = ic_tx_ordset_en  & wr_en;
  assign ic_tx_paysz_we   = ic_tx_paysz_en   & wr_en;
  assign ic_txdr_we       = ic_txdr_en       & wr_en;
  assign ic_rx_ordext1_we = ic_rx_ordext1_en & wr_en;
  assign ic_rx_ordext2_we = ic_rx_ordext2_en & wr_en;

  /*------------------------------------------------------------------------------
  --   Control signal generation
  ------------------------------------------------------------------------------*/
  assign rxdr_rd      = ic_rxdr_en & rd_en;
  assign ucpden       = ic_cfg1[31];
  assign rx_ordset_en = ic_cfg1[28:20];
  assign psc_usbpdclk = ic_cfg1[19:17];
  assign transwin     = ic_cfg1[15:11];
  assign ifrgap       = ic_cfg1[10:06];
  assign hbitclkdiv   = ic_cfg1[05:00];

  assign ic_cfg1_s    = ic_cfg1;
  assign ic_cfg2_s    = ic_cfg2;
  assign ic_cr_s      = ic_cr;
  assign ic_sr_s      = ic_sr;
  assign tx_mode      = ic_cr[1:0];
  assign tx_hrst      = ic_cr[3];
  assign transmit_en  = ic_cr[2];

  /*------------------------------------------------------------------------------
  --  analog interface
  ------------------------------------------------------------------------------*/
  always @(*) begin
    case(cc1_compout)
      3'b000 : vstate_cc1 = 2'd0;
      3'b001 : vstate_cc1 = 2'd1;
      3'b010 : vstate_cc1 = 2'd2;
      3'b100 : vstate_cc1 = 2'd3;
      default : vstate_cc1 = 2'd0;
    endcase
  end

  always @(*) begin
    case(cc2_compout)
      3'b000 : vstate_cc2 = 2'd0;
      3'b001 : vstate_cc2 = 2'd1;
      3'b010 : vstate_cc2 = 2'd2;
      3'b100 : vstate_cc2 = 2'd3;
      default : vstate_cc2 = 2'd0;
    endcase
  end

  assign phy_cc1_com = ~ic_cr[6];
  assign phy_cc2_com = ic_cr[6];
  assign cc1_det_en  = ~ic_cr[20];
  assign cc2_det_en  = ~ic_cr[21];
  assign phy_en      = ic_cr[11:10];
  assign set_c500    = (ic_cr[8:7] == 2'b01) ? 1'b1 : 1'b0;
  assign set_c1500   = (ic_cr[8:7] == 2'b10) ? 1'b1 : 1'b0;
  assign set_c3000   = (ic_cr[8:7] == 2'b11) ? 1'b1 : 1'b0;
  assign set_pd      = ic_cr[9];
  assign source_en   = ~ic_cr[9];
  assign phy_rx_en   = ic_cr[5];

  // ----------------------------------------------------------
  // -- Synchronization registers for flags input from ic_clk domain
  // ----------------------------------------------------------
  wire [6:0] tx_status_src     ;
  wire [6:0] tx_status_src_sync;
  assign tx_status_src  = tx_status;
  assign tx_status_sync = tx_status_src_sync;
  apb_ucpd_bcm21 #(.WIDTH(7)) u_tx_status_psyzr (
    .clk_d   (pclk              ),
    .rst_d_n (presetn           ),
    .init_d_n(1'b1              ),
    .test    (1'b0              ),
    .data_s  (tx_status_src     ),
    .data_d  (tx_status_src_sync)
  );

  wire [5:0] rx_status_src     ;
  wire [5:0] rx_status_src_sync;
  assign rx_status_src  = rx_status;
  assign rx_status_sync = rx_status_src_sync;
  apb_ucpd_bcm21 #(.WIDTH(6)) u_rx_status_psyzr (
    .clk_d   (pclk              ),
    .rst_d_n (presetn           ),
    .init_d_n(1'b1              ),
    .test    (1'b0              ),
    .data_s  (rx_status_src     ),
    .data_d  (rx_status_src_sync)
  );

  reg [6:0] tx_status_sync_d;
  reg [5:0] rx_status_sync_d;
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0) begin
      tx_status_sync_d <= 7'b0;
      rx_status_sync_d <= 6'b0;
    end
    else begin
      tx_status_sync_d <= tx_status_sync;
      rx_status_sync_d <= rx_status_sync;
    end
  end

  assign tx_status_sync_red = (tx_status_sync & ~tx_status_sync_d);
  assign rx_status_sync_red = (rx_status_sync & ~rx_status_sync_d);
  /*------------------------------------------------------------------------------
  --  generate typec_evt1, typec_evt2 and its positive edge for SR
  ------------------------------------------------------------------------------*/
  wire [1:0] vstate_cc1_src     ;
  wire [1:0] vstate_cc1_src_sync;
  assign vstate_cc1_src  = vstate_cc1;
  assign vstate_cc1_sync = vstate_cc1_src_sync;
  apb_ucpd_bcm21 #(.WIDTH(2)) u_vstate_cc1_psyzr (
    .clk_d   (pclk               ),
    .rst_d_n (presetn            ),
    .init_d_n(1'b1               ),
    .test    (1'b0               ),
    .data_s  (vstate_cc1_src     ),
    .data_d  (vstate_cc1_src_sync)
  );

  wire [1:0] vstate_cc2_src     ;
  wire [1:0] vstate_cc2_src_sync;
  assign vstate_cc2_src  = vstate_cc2;
  assign vstate_cc2_sync = vstate_cc2_src_sync;
  apb_ucpd_bcm21 #(.WIDTH(2)) u_vstate_cc2_psyzr (
    .clk_d   (pclk               ),
    .rst_d_n (presetn            ),
    .init_d_n(1'b1               ),
    .test    (1'b0               ),
    .data_s  (vstate_cc2_src     ),
    .data_d  (vstate_cc2_src_sync)
  );

  reg [1:0] vstate_cc1_nxt;
  reg [1:0] vstate_cc2_nxt;
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0) begin
      vstate_cc1_nxt <= 2'b0;
      vstate_cc2_nxt <= 2'b0;
    end
    else begin
      vstate_cc1_nxt <= vstate_cc1_sync;
      vstate_cc2_nxt <= vstate_cc2_sync;
    end
  end

  assign typec_evt1 = vstate_cc1_nxt != vstate_cc1_sync;
  assign typec_evt2 = vstate_cc2_nxt != vstate_cc2_sync;

  reg [1:0] typec_evt1_r;
  reg [1:0] typec_evt2_r;
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0) begin
      typec_evt1_r <= 2'b0;
      typec_evt2_r <= 2'b0;
    end
    else begin
      typec_evt1_r <= {typec_evt1_r[0], typec_evt1};
      typec_evt2_r <= {typec_evt2_r[0], typec_evt2};
    end
  end

  assign typec_evt1_red = ~typec_evt1_r[1] & typec_evt1_r[0];
  assign typec_evt2_red = ~typec_evt2_r[1] & typec_evt2_r[0];

  /*------------------------------------------------------------------------------
  --  generate frs_evt positive edge for SR
  ------------------------------------------------------------------------------*/
  reg [1:0] frs_evt_r;
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      frs_evt_r <= 2'b0;
    else
      frs_evt_r <= {frs_evt_r[0], frs_evt};
  end

  assign frs_evt_red = ~frs_evt_r[1] & frs_evt_r[0];

  /*------------------------------------------------------------------------------
  --  Below is APB BUS write UCPD registers
  ------------------------------------------------------------------------------*/

  // apb write UCPD configuration register 1 (UCPD_CFG1)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_cfg1 <= 32'b0;
    // else if(hard_rst)
    //   ic_cfg1[31] <= 1'b0;
    else if (ic_cfg1_we == 1'b1) begin
      if(ipwdata[31])
        ic_cfg1[31] <= ipwdata[31];
      else
        ic_cfg1[30:0] <= ipwdata[30:0];
    end
  end

  // apb write UCPD configuration register 2 (UCPD_CFG2)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_cfg2 <= 32'b0;
    else if (ic_cfg2_we == 1'b1 && ucpden == 1'b0)
      ic_cfg2 <= ipwdata;
  end

  // apb write UCPD control register (UCPD_CR)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_cr <= 32'b0;
    else if(ucpden) begin
      if (ic_cr_we == 1'b1)
        ic_cr <= ipwdata;
      else if(txhrst_clr)
        ic_cr[3] <= 1'b0;
      else if(txsend_clr)
        ic_cr[2] <= 1'b0;
    end
  end

  // apb write UCPD Interrupt Mask Register (UCPD_IMR)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_imr <= 32'b0;
    else if(ic_imr_we == 1'b1 && ucpden)
      ic_imr <= ipwdata;
  end

  // apb write UCPD Interrupt Clear Register (UCPD_ICR)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_icr <= 32'b0;
    else if(ic_icr_we == 1'b1 && ucpden)
      ic_icr <= ipwdata;
  end

  // apb write UCPD Tx Ordered Set Type Register (UCPD_TX_ORDSET)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_tx_ordset <= 32'b0;
    else if (ic_tx_ordset_we == 1'b1 && ucpden)
      ic_tx_ordset <= ipwdata;
  end

  // apb write UCPD Tx Paysize Register (UCPD_TX_PAYSZ)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_tx_paysz <= 32'b0;
    else if (ic_tx_paysz_we == 1'b1 && ucpden)
      ic_tx_paysz <= ipwdata;
  end

  // apb write UCPD Tx Data Register (UCPD_TXDR)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_txdr <= 32'b0;
    else if(ic_txdr_we == 1'b1 && ucpden)
      ic_txdr <= ipwdata;
  end

  // apb write UCPD Rx Ordered Set Extension Register #1 (UCPD_RX_ORDEXT1)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_rx_ordext1 <= 32'b0;
    else if (ic_rx_ordext1_we == 1'b1 && ucpden == 1'b0)
      ic_rx_ordext1 <= ipwdata;
  end

  // apb write UCPD Rx Ordered Set Extension Register #2 (UCPD_RX_ORDEXT2)
  always @(posedge pclk or negedge presetn) begin
    if (presetn == 1'b0)
      ic_rx_ordext2 <= 32'b0;
    else if (ic_rx_ordext2_we == 1'b1 && ucpden == 1'b0)
      ic_rx_ordext2 <= ipwdata;
  end

  /*------------------------------------------------------------------------------
  --  generate UCPD Status Register (UCPD_SR) read data
  ------------------------------------------------------------------------------*/
  always @(posedge pclk or negedge presetn) begin
    if(presetn == 1'b0)
      ic_sr <= 31'b0;
    else begin
      // TYPEC_VSTATE_CC2[1:0]:This status shows the DC level seen on the CC2 pin
      ic_sr[19:18] <= vstate_cc2;
      // TYPEC_VSTATE_CC1[1:0]:This status shows the DC level seen on the CC1 pin
      ic_sr[17:16] <= vstate_cc1;
      // FRSEVT: Fast Role Swap detection event.
      if(ic_icr[20])
        ic_sr[20] <= 1'b0;
      else if(frs_evt_red)
        ic_sr[20] <= 1'b1;

      // TYPECEVT2: Type C voltage level event on CC2 pin.
      if(ic_icr[15])
        ic_sr[15] <= 1'b0;
      else if(typec_evt2_red)
        ic_sr[15] <= 1'b1;

      // TYPECEVT1: Type C voltage level event on CC1 pin.
      if(ic_icr[14])
        ic_sr[14] <= 1'b0;
      else if(typec_evt1_red)
        ic_sr[14] <= 1'b1;

      // RXERR: Receive message not completed OK
      if(ic_icr[13])
        ic_sr[13] <= 1'b0;
      else if(rx_status_sync_red[5])
        ic_sr[13] <= 1'b1;

      // RXMSGEND: Rx message received
      if(ic_icr[12])
        ic_sr[12] <= 1'b0;
      else if(rx_status_sync_red[4])
        ic_sr[12] <= 1'b1;

      // RXOVR: Rx data overflow interrupt
      if(ic_icr[11])
        ic_sr[11] <= 1'b0;
      else if(rx_status_sync_red[3])
        ic_sr[11] <= 1'b1;

      // RXHRSTDET: Rx Hard Reset detect interrupt
      if(ic_icr[10])
        ic_sr[10] <= 1'b0;
      else if(rx_status_sync_red[2])
        ic_sr[10] <= 1'b1;

      // RXORDDET: Rx ordered set (4 K-codes) detected interrupt
      if(ic_icr[9])
        ic_sr[9] <= 1'b0;
      else if(rx_status_sync_red[1])
        ic_sr[9] <= 1'b1;

      // RXNE: Receive data register not empty interrupt
      if(rxdr_rd)
        ic_sr[8] <= 1'b0;
      else if(rx_status_sync_red[0])
        ic_sr[8] <= 1'b1;

      // TXUND: Tx data underrun condition interrupt
      if(ic_icr[6])
        ic_sr[6] <= 1'b0;
      else if(tx_status_sync_red[6])
        ic_sr[6] <= 1'b1;

      // HRSTSENT: HRST sent interrupt
      if(ic_icr[5])
        ic_sr[5] <= 1'b0;
      else if(tx_status_sync_red[5])
        ic_sr[5] <= 1'b1;

      // HRSTDISC: HRST discarded interrupt
      if(ic_icr[4])
        ic_sr[4] <= 1'b0;
      else if(tx_status_sync_red[4])
        ic_sr[4] <= 1'b1;

      // TXMSGABT: Transmit message abort interrupt
      if(ic_icr[3])
        ic_sr[3] <= 1'b0;
      else if(tx_status_sync_red[3])
        ic_sr[3] <= 1'b1;

      // TXMSGSENT: Transmit message sent interrupt
      if(ic_icr[2])
        ic_sr[2] <= 1'b0;
      else if(tx_status_sync_red[2])
        ic_sr[2] <= 1'b1;

      //  TXMSGDISC: Transmit message discarded interrupt
      if(ic_icr[1])
        ic_sr[1] <= 1'b0;
      else if(tx_status_sync_red[1])
        ic_sr[1] <= 1'b1;

      // TXIS: Transmit interrupt status
      if(txdr_we)
        ic_sr[0] <= 1'b0;
      else if(tx_status_sync_red[0])
        ic_sr[0] <= 1'b1;
    end
  end

  /*------------------------------------------------------------------------------
  --  APB read data mux
  --  The data from the selected register is
  --  placed on a zero-padded 32-bit read data bus.
  --  this is a reverse case and parallel case
  ------------------------------------------------------------------------------*/
  always @ (*) begin : IPRDATA_PROC
    iprdata = 32'b0;
    case (1'b1)
      ic_cfg1_en       : iprdata  = ic_cfg1_s       ;
      ic_cfg2_en       : iprdata  = ic_cfg2_s       ;
      ic_cr_en         : iprdata  = ic_cr_s         ;
      ic_imr_en        : iprdata  = ic_imr_s        ;
      ic_sr_en         : iprdata  = ic_sr_s         ;
      ic_tx_paysz_en   : iprdata  = ic_tx_paysz_s   ;
      ic_txdr_en       : iprdata  = ic_txdr_s       ;
      ic_rx_ordset_en  : iprdata  = ic_rx_ordset_s  ;
      ic_rx_paysz_en   : iprdata  = ic_rx_paysz_s   ;
      ic_rxdr_en       : iprdata  = ic_rxdr_s       ;
      ic_rx_ordext1_en : iprdata  = ic_rx_ordext1_s ;
      ic_rx_ordext2_en : iprdata  = ic_rx_ordext2_s ;
    endcase
  end

endmodule