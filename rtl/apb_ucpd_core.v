module apb_ucpd_core (
  input         ic_clk      , //usbpd clock(HSI16)
  input         ic_rst_n    ,
  input         ucpden      ,
  input  [ 4:0] transwin    , // use half bit clock to achieve a legal tTransitionWindow
  input  [ 4:0] ifrgap      , // Interframe gap
  input  [ 2:0] psc_usbpdclk, // Pre-scaler for UCPD_CLK
  input  [ 5:0] hbitclkdiv  , // Clock divider values to generate a half-bit clock
  input         tx_hrst     ,
  input         cc_in       ,
  input         transmit_en ,
  input         rxdr_rd     ,
  input         tx_ordset_we,
  input         txdr_we     ,
  input  [ 8:0] rx_ordset_en,
  input  [ 1:0] tx_mode     ,
  input  [ 1:0] rxfilte     ,
  input  [19:0] tx_ordset   ,
  input  [ 7:0] ic_txdr     ,
  input  [ 9:0] tx_paysize  ,
  output        txhrst_clr  ,
  output        txsend_clr  ,
  output [ 6:0] tx_status   ,
  output [ 5:0] rx_status   ,
  output [ 6:0] rx_ordset   ,
  output [ 9:0] rx_byte_cnt ,
  output [ 7:0] rx_byte     ,
  output        hrst_vld    ,
  output        ic_cc_out   ,
  output        cc_oen
);

  wire        eop_ok          ;
  wire        bit_clk_red     ;
  wire        hbit_clk_red    ;
  wire        ucpd_clk_red    ;
  wire        transwin_en     ;
  wire        ifrgap_en       ;
  wire        drain           ;
  wire        ld_crc_n        ;
  wire [ 7:0] data_in         ;
  wire [31:0] crc_in          ;
  wire        draining        ;
  wire        drain_done      ;
  wire [ 7:0] data_out        ;
  wire [31:0] crc_tx_out      ;
  wire [31:0] crc_tx_in       ;
  wire        tx_hrst_flag    ;
  wire        tx_crst_flag    ;
  wire        pre_en          ;
  wire        bmc_en          ;
  wire        sop_en          ;
  wire        data_en         ;
  wire        crc_en          ;
  wire        eop_en          ;
  wire        bist_en         ;
  wire        txfifo_ld_en    ;
  wire        tx_msg_disc     ;
  wire        tx_hrst_disc    ;
  wire        tx_hrst_red     ;
  wire        tx_crst_red     ;
  wire        tx_bit          ;
  wire        hard_rst        ;
  wire        rx_bit_cmplt    ;
  wire        decode_bmc      ;
  wire        crc_ok          ;
  wire        receive_en      ;
  wire        ic_cc_in        ;
  wire        crst_vld        ;
  wire        dec_rxbit_en    ;
  wire        tx_sop_cmplt    ;
  wire        tx_crc_cmplt    ;
  wire        txdr_req        ;
  wire        rx_bit5_cmplt   ;
  wire        rx_sop_cmplt    ;
  wire        init_n          ;
  wire        enable          ;
  wire        bypass_prescaler;
  wire        pre_rxbit_edg   ;
  wire        rx_pre_cmplt    ;
  wire        tx_wait_cmplt   ;
  wire        tx_sop_rst_cmplt;
  wire        wait_en         ;
  wire        rxfifo_wr_en    ;
  wire        rx_pre_en       ;
  wire        tx_eop_cmplt    ;
  wire        hrst_tx_en      ;

  assign ic_cc_in  = cc_in;
  assign data_in   = receive_en ? rx_byte : ic_txdr;
  assign enable    = receive_en ? rxfifo_wr_en : txfifo_ld_en;
  assign init_n    = receive_en ? ~rx_pre_en : ~pre_en;
  assign crc_tx_in = crc_tx_out;

  apb_ucpd_clk_gen u_apb_ucpd_clk_gen (
    .ic_clk          (ic_clk          ),
    .ic_rst_n        (ic_rst_n        ),
    .tx_eop_cmplt    (tx_eop_cmplt    ),
    .tx_sop_rst_cmplt(tx_sop_rst_cmplt),
    .transmit_en     (transmit_en     ),
    .bmc_en          (bmc_en          ),
    .wait_en         (wait_en         ),
    .transwin        (transwin        ),
    .ifrgap          (ifrgap          ),
    .psc_usbpdclk    (psc_usbpdclk    ),
    .hbitclkdiv      (hbitclkdiv      ),
    .bit_clk_red     (bit_clk_red     ),
    .hbit_clk_red    (hbit_clk_red    ),
    .ucpd_clk_red    (ucpd_clk_red    ),
    .ucpd_clk        (ucpd_clk        ),
    .bypass_prescaler(bypass_prescaler),
    .transwin_en     (transwin_en     ),
    .ifrgap_en       (ifrgap_en       )
  );

  apb_ucpd_bmc_filter u_apb_ucpd_bmc_filter (
    .ic_clk          (ic_clk          ),
    .ic_rst_n        (ic_rst_n        ),
    .ucpden          (ucpden          ),
    .ic_cc_in        (ic_cc_in        ),
    .bit_clk_red     (bit_clk_red     ),
    .hbit_clk_red    (hbit_clk_red    ),
    .ucpd_clk        (ucpd_clk_red    ),
    .ucpd_clk_red    (ucpd_clk_red    ),
    .bypass_prescaler(bypass_prescaler),
    .rxfilte         (rxfilte         ),
    .hrst_vld        (hrst_vld        ),
    .crst_vld        (crst_vld        ),
    .rx_pre_en       (rx_pre_en       ),
    .rx_sop_en       (rx_sop_en       ),
    .rx_data_en      (rx_data_en      ),
    .tx_eop_cmplt    (tx_eop_cmplt    ),
    .eop_ok          (eop_ok          ),
    .pre_en          (pre_en          ),
    .sop_en          (sop_en          ),
    .bmc_en          (bmc_en          ),
    .dec_rxbit_en    (dec_rxbit_en    ),
    .tx_bit          (tx_bit          ),
    .decode_bmc      (decode_bmc      ),
    .ic_cc_out       (ic_cc_out       ),
    .rx_bit_cmplt    (rx_bit_cmplt    ),
    .rx_pre_cmplt    (rx_pre_cmplt    ),
    .rx_bit5_cmplt   (rx_bit5_cmplt   ),
    .receive_en      (receive_en      )
  );

  apb_ucpd_pcrc u_apb_ucpd_pcrc (
    .ic_clk    (ic_clk    ),
    .ic_rst_n  (ic_rst_n  ),
    .init_n    (init_n    ),
    .enable    (enable    ),
    .drain     (drain     ),
    .ld_crc_n  (ld_crc_n  ),
    .data_in   (data_in   ),
    .crc_in    (crc_in    ),
    .draining  (draining  ),
    .drain_done(drain_done),
    .crc_ok    (crc_ok    ),
    .data_out  (data_out  ),
    .crc_out   (crc_tx_out)
  );

  apb_ucpd_data_tx u_apb_ucpd_data_tx (
    .ic_clk       (ic_clk       ),
    .ic_rst_n     (ic_rst_n     ),
    .tx_hrst      (tx_hrst      ),
    .bit_clk_red  (bit_clk_red  ),
    .transmit_en  (transmit_en  ),
    .tx_sop_cmplt (tx_sop_cmplt ),
    .tx_crc_cmplt (tx_crc_cmplt ),
    .tx_wait_cmplt(tx_wait_cmplt),
    .tx_data_cmplt(tx_data_cmplt),
    .tx_eop_cmplt (tx_eop_cmplt ),
    .tx_hrst_flag (tx_hrst_flag ),
    .tx_crst_flag (tx_crst_flag ),
    .txhrst_clr   (txhrst_clr   ),
    .txsend_clr   (txsend_clr   ),
    .hrst_tx_en   (hrst_tx_en   ),
    .txdr_req     (txdr_req     ),
    .pre_en       (pre_en       ),
    .bmc_en       (bmc_en       ),
    .sop_en       (sop_en       ),
    .data_en      (data_en      ),
    .crc_en       (crc_en       ),
    .eop_en       (eop_en       ),
    .bist_en      (bist_en      ),
    .tx_ordset_we (tx_ordset_we ),
    .txfifo_ld_en (txfifo_ld_en ),
    .txdr_we      (txdr_we      ),
    .tx_mode      (tx_mode      ),
    .tx_msg_disc  (tx_msg_disc  ),
    .tx_hrst_disc (tx_hrst_disc ),
    .ic_txdr      (ic_txdr      ),
    .crc_in       (crc_tx_in    ),
    .tx_ordset    (tx_ordset    ),
    .tx_status    (tx_status    ),
    .tx_hrst_red  (tx_hrst_red  ),
    .tx_crst_red  (tx_crst_red  ),
    .tx_bit       (tx_bit       )
  );

  apb_ucpd_data_rx u_apb_ucpd_data_rx (
    .ic_clk       (ic_clk       ),
    .ucpd_clk     (ucpd_clk     ),
    .ic_rst_n     (ic_rst_n     ),
    .hard_rst     (hard_rst     ),
    .rx_bit5_cmplt(rx_bit5_cmplt),
    .rx_bit_cmplt (rx_bit_cmplt ),
    .rx_pre_en    (rx_pre_en    ),
    .rx_sop_en    (rx_sop_en    ),
    .rx_data_en   (rx_data_en   ),
    .rxdr_rd      (rxdr_rd      ),
    .decode_bmc   (decode_bmc   ),
    .crc_ok       (crc_ok       ),
    .dec_rxbit_en (dec_rxbit_en ),
    .rx_ordset_en (rx_ordset_en ),
    .rx_status    (rx_status    ),
    .rx_ordset    (rx_ordset    ),
    .rxfifo_wr_en (rxfifo_wr_en ),
    .rx_sop_cmplt (rx_sop_cmplt ),
    .rx_byte_cnt  (rx_byte_cnt  ),
    .hrst_vld     (hrst_vld     ),
    .crst_vld     (crst_vld     ),
    .eop_ok       (eop_ok       ),
    .rx_byte      (rx_byte      )
  );

  apb_ucpd_fsm u_apb_ucpd_fsm (
    .ic_clk          (ic_clk          ),
    .ucpd_clk        (ucpd_clk        ),
    .ic_rst_n        (ic_rst_n        ),
    .ucpden          (ucpden          ),
    .tx_hrst         (tx_hrst         ),
    .transmit_en     (transmit_en     ),
    .receive_en      (receive_en      ),
    .eop_ok          (eop_ok          ),
    .bit_clk_red     (bit_clk_red     ),
    .tx_paysize      (tx_paysize      ),
    .crc_ok          (crc_ok          ),
    .rx_bit_cmplt    (rx_bit_cmplt    ),
    .rx_sop_cmplt    (rx_sop_cmplt    ),
    .pre_rxbit_edg   (pre_rxbit_edg   ),
    .tx_mode         (tx_mode         ),
    .tx_status       (tx_status       ),
    .transwin_en     (transwin_en     ),
    .ifrgap_en       (ifrgap_en       ),
    .tx_hrst_red     (tx_hrst_red     ),
    .tx_crst_red     (tx_crst_red     ),
    .rx_pre_cmplt    (rx_pre_cmplt    ),
    .hrst_vld        (hrst_vld        ),
    .crst_vld        (crst_vld        ),
    .tx_hrst_flag    (tx_hrst_flag    ),
    .tx_crst_flag    (tx_crst_flag    ),
    .hrst_tx_en      (hrst_tx_en      ),
    .bmc_en          (bmc_en          ),
    .tx_sop_cmplt    (tx_sop_cmplt    ),
    .tx_wait_cmplt   (tx_wait_cmplt   ),
    .tx_crc_cmplt    (tx_crc_cmplt    ),
    .tx_data_cmplt   (tx_data_cmplt   ),
    .tx_sop_rst_cmplt(tx_sop_rst_cmplt),
    .tx_eop_cmplt    (tx_eop_cmplt    ),
    .tx_msg_disc     (tx_msg_disc     ),
    .tx_hrst_disc    (tx_hrst_disc    ),
    .txfifo_ld_en    (txfifo_ld_en    ),
    .cc_oen          (cc_oen          ),
    .dec_rxbit_en    (dec_rxbit_en    ),
    .txdr_req        (txdr_req        ),
    .rx_pre_en       (rx_pre_en       ),
    .rx_sop_en       (rx_sop_en       ),
    .rx_data_en      (rx_data_en      ),
    .pre_en          (pre_en          ),
    .sop_en          (sop_en          ),
    .data_en         (data_en         ),
    .crc_en          (crc_en          ),
    .eop_en          (eop_en          ),
    .wait_en         (wait_en         ),
    .bist_en         (bist_en         )
  );


endmodule