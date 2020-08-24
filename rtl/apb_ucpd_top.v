module apb_ucpd_top (
  input         pclk       , //# APB Clock Signal, used for the bus interface unit, can be asynchronous to the I2C clocks
  input         presetn    , //# APB Reset Signal (active low)
  input         psel       , //# APB Peripheral Select Signal: lasts for two pclk cycles; when asserted indicates that the peripheral has been selected for read/write operation
  input         penable    , //# Strobe Signal: asserted for a single pclk cycle, used for timing read/write operations
  input         pwrite     , //# Write Signal: when high indicates a write access to the peripheral; when low indicates a read access
  input  [ 7:0] paddr      , //# Address Bus: uses the lower 7 bits of the address bus for register decode, ignores bits 0 and 1 so that the 8 registers are on 32 bit boundaries
  input  [31:0] pwdata     , //Write Data Bus: driven by the
  input         ic_clk     , //usbpd clock(HSI16)
  input         ic_rst_n   ,
  input  [ 2:0] cc1_compout, // SR.17:16  TYPEC_VSTATE_CC1
  input  [ 2:0] cc2_compout, // SR.19:18  TYPEC_VSTATE_CC2
  input         cc1_datai  , // cc1_in
  input         cc2_datai  , // cc2_in
  output [ 1:0] phy_en     , // CR.11:10 CCENABLE
  output        set_c500   , // CR.8:7 ANASUBMODE
  output        set_c1500  , // CR.8:7 ANASUBMODE
  output        set_c3000  , // CR.8:7 ANASUBMODE
  output        set_pd     , // CR.9 ANAMODE 1
  output        source_en  , // CR.9 ANAMODE 0
  output        phy_rx_en  , // CR.5 PHYRXEN
  output        cc1_det_en , // CR.20 CC1TCDIS
  output        cc2_det_en , // CR.21 CC2TCDIS
  output        phy_cc1_com, // CR.6 PHYCCSEL 0
  output        phy_cc2_com, // CR.6 PHYCCSEL 1
  output        cc1_datao  , // cc1_out
  output        cc1_dataoen, // cc1_oen
  output        cc2_datao  , // cc2_out
  output        cc2_dataoen, // cc2_oen
  output        ucpd_intr  ,
  output [31:0] prdata
);

  // ----------------------------------------------------------
  // -- local registers and wires
  // ----------------------------------------------------------
  //registers

  //wires
  wire [ 3:0] byte_en     ;
  wire [ 5:0] reg_addr    ;
  wire [31:0] ipwdata     ;
  wire [31:0] iprdata     ;
  wire        ucpden      ;
  wire [ 4:0] transwin    ;
  wire [ 4:0] ifrgap      ;
  wire [ 5:0] hbitclkdiv  ;
  wire [ 2:0] psc_usbpdclk;
  wire [19:0] tx_ordset   ;
  wire [ 9:0] tx_paysize  ;
  wire        wr_en       ;
  wire        rd_en       ;
  wire        txhrst_clr  ;
  wire        txsend_clr  ;
  wire        frs_evt     ;
  wire [ 1:0] vstate_cc1  ;
  wire [ 1:0] vstate_cc2  ;
  wire [ 6:0] tx_status   ;
  wire [ 5:0] rx_status   ;
  wire [ 6:0] rx_ordset   ;
  wire [ 9:0] rx_byte_cnt ;
  wire [ 7:0] rx_byte     ;
  wire        hrst_vld    ;
  wire        tx_hrst     ;
  wire        rxdr_rd     ;
  wire [ 1:0] tx_mode     ;
  wire        tx_ordset_we;
  wire [ 8:0] rx_ordset_en;
  wire        txdr_we     ;
  wire [ 7:0] ic_txdr     ;
  wire        ic_cc_out   ;
  wire [ 1:0] rxfilte     ;
  wire transmit_en;
  wire cc_oen;

  assign cc_out      = ic_cc_out;
  assign cc_in       = phy_cc1_com ? cc1_datai : cc2_datai;
  assign cc1_dataoen = phy_cc1_com ? cc_oen : 1'b0;
  assign cc2_dataoen = phy_cc2_com ? cc_oen : 1'b0;
  assign cc1_datao   = phy_cc1_com ? cc_out : 1'b0;
  assign cc2_datao   = phy_cc2_com ? cc_out : 1'b0;

  apb_ucpd_biu u_apb_ucpd_biu (
    .pclk    (pclk    ), // APB clock
    .presetn (presetn ), // APB reset
    .psel    (psel    ), // APB slave select
    .pwrite  (pwrite  ), // APB write/read
    .penable (penable ), // APB enable
    .paddr   (paddr   ), // APB address
    .pwdata  (pwdata  ), // APB write data bus
    .iprdata (iprdata ), // Internal read data bus
    .wr_en   (wr_en   ), // Write enable signal
    .rd_en   (rd_en   ), // Read enable signal
    .byte_en (byte_en ), // Active byte lane signal
    .reg_addr(reg_addr), // Register address offset
    .ipwdata (ipwdata ), // Internal write data bus
    .prdata  (prdata  )  // APB read data bus
  );

  apb_ucpd_if u_apb_ucpd_if (
    .pclk        (pclk        ),
    .presetn     (presetn     ),
    .wr_en       (wr_en       ),
    .rd_en       (rd_en       ),
    .reg_addr    (reg_addr    ),
    .ipwdata     (ipwdata     ),
    .txhrst_clr  (txhrst_clr  ),
    .txsend_clr  (txsend_clr  ),
    .frs_evt     (frs_evt     ),
    .tx_status   (tx_status   ),
    .rx_status   (rx_status   ),
    .rx_ordset   (rx_ordset   ),
    .rx_byte_cnt (rx_byte_cnt ),
    .rx_byte     (rx_byte     ),
    .hrst_vld    (hrst_vld    ),
    .cc1_compout (cc1_compout ),
    .cc2_compout (cc2_compout ),
    .phy_en      (phy_en      ),
    .set_c500    (set_c500    ),
    .set_c1500   (set_c1500   ),
    .set_c3000   (set_c3000   ),
    .set_pd      (set_pd      ),
    .source_en   (source_en   ),
    .phy_rx_en   (phy_rx_en   ),
    .cc1_det_en  (cc1_det_en  ),
    .cc2_det_en  (cc2_det_en  ),
    .phy_cc1_com (phy_cc1_com ),
    .phy_cc2_com (phy_cc2_com ),
    .ucpden      (ucpden      ),
    .transwin    (transwin    ),
    .ifrgap      (ifrgap      ),
    .hbitclkdiv  (hbitclkdiv  ),
    .psc_usbpdclk(psc_usbpdclk),
    .rx_ordset_en(rx_ordset_en),
    .tx_hrst     (tx_hrst     ),
    .rxdr_rd     (rxdr_rd     ),
    .transmit_en (transmit_en ),
    .tx_mode     (tx_mode     ),
    .ucpd_intr   (ucpd_intr   ),
    .tx_ordset_we(tx_ordset_we),
    .tx_paysize  (tx_paysize  ),
    .txdr_we     (txdr_we     ),
    .rxfilte     (rxfilte     ),
    .tx_ordset   (tx_ordset   ),
    .ic_txdr     (ic_txdr     ),
    .iprdata     (iprdata     )
  );

  apb_ucpd_core u_apb_ucpd_core (
    .ic_clk      (ic_clk      ),
    .ic_rst_n    (ic_rst_n    ),
    .ucpden      (ucpden      ),
    .transwin    (transwin    ),
    .ifrgap      (ifrgap      ),
    .psc_usbpdclk(psc_usbpdclk),
    .hbitclkdiv  (hbitclkdiv  ),
    .tx_hrst     (tx_hrst     ),
    .cc_in       (cc_in       ),
    .transmit_en (transmit_en ),
    .rxdr_rd     (rxdr_rd     ),
    .tx_ordset_we(tx_ordset_we),
    .rx_ordset_en(rx_ordset_en),
    .txdr_we     (txdr_we     ),
    .tx_mode     (tx_mode     ),
    .rxfilte     (rxfilte     ),
    .tx_ordset   (tx_ordset   ),
    .ic_txdr     (ic_txdr     ),
    .tx_paysize  (tx_paysize  ),
    .txhrst_clr  (txhrst_clr  ),
    .txsend_clr  (txsend_clr  ),
    .tx_status   (tx_status   ),
    .rx_status   (rx_status   ),
    .rx_ordset   (rx_ordset   ),
    .rx_byte_cnt (rx_byte_cnt ),
    .rx_byte     (rx_byte     ),
    .hrst_vld    (hrst_vld    ),
    .ic_cc_out   (ic_cc_out   ),
    .cc_oen      (cc_oen      )
  );


endmodule