
module apb_ucpd_bmc_filter (
  input            ic_clk          , // peripherial clock
  input            ic_rst_n        , // ic reset signal active low
  input            ucpden          ,
  input            ic_cc_in        , // Input CC rxd signal
  input            bit_clk_red     ,
  input            hbit_clk_red    ,
  input            ucpd_clk        ,
  input            ucpd_clk_red    ,
  input            bypass_prescaler,
  input      [1:0] rxfilte         ,
  input            hrst_vld        ,
  input            crst_vld        ,
  input            rx_pre_en       ,
  input            rx_sop_en       ,
  input            rx_data_en      ,
  input            tx_eop_cmplt,
  input            eop_ok          ,
  input            pre_en          ,
  input            sop_en          ,
  input            bmc_en          ,
  input            dec_rxbit_en    ,
  input            tx_bit          ,
  output reg       decode_bmc      , // decode input cc bmc
  output           ic_cc_out       ,
  output           rx_bit_cmplt    ,
  output           rx_pre_cmplt    ,
  output           rx_bit5_cmplt   ,
  output reg       receive_en
);
  // `include "parameter_def.v"
  // ----------------------------------------------------------
  // -- local registers and wires
  // ----------------------------------------------------------
  //regs
  reg        cc_data_int     ;
  reg        training_en     ;
  reg [ 1:0] simple_cnt      ;
  reg [10:0] UI_cntA         ;
  reg [10:0] UI_cntB         ;
  reg [10:0] UI_cntC         ;
  reg [10:0] th_1UI          ;
  reg        rx_bmc          ;
  reg [10:0] data_cnt        ;
  reg        data1_flag      ;
  reg        tx_bmc          ;
  reg [ 10:0] pre_rxbit_cnt   ;
  reg        cc_in_d         ;
  reg        cc_data_int_nxt ;
  reg [10:0] UI_ave          ;
  reg [11:0] UI_sum          ;
  reg [ 2:0] ave_cnt         ;
  reg [10:0] rx_pre_hbit_cnt ;
  reg [10:0] rx_pre_lbit_cnt ;
  reg [10:0] rx_pre_hbit_time;
  reg [10:0] rx_pre_lbit_time;
  reg [10:0] rx_hbit_cnt     ;
  reg [10:0] rx_lbit_cnt     ;
  reg [ 2:0] rxbit_cnt       ;
  reg        cc_in_vld       ;
  reg [10:0] UI_H_cnt        ;
  reg [10:0] UI_L_cnt        ;

  //wires
  wire cc_in_edg     ;
  reg  first_2bit_end;
  reg  cc_in_sync    ;
  wire rxfilt_2n3    ;
  wire rxfilt_dis    ;
  wire cc_in_sync_nxt;
  wire rx_hbit_cmplt ;
  wire rx_lbit_cmplt ;
  wire pre_rxbit_edg ;

  assign rx_pre_cmplt  = rx_pre_en && (pre_rxbit_cnt == `RX_PRE_EDG);
  assign rx_bit_cmplt  = decode_bmc ? rx_hbit_cmplt : rx_lbit_cmplt;
  assign cc_int        = rxfilt_dis ? cc_in_sync : cc_data_int;
  assign cc_int_nxt    = rxfilt_dis ? cc_in_sync_nxt : cc_data_int_nxt;
  assign rx_hbit_cmplt = (rx_hbit_cnt == rx_pre_hbit_time);
  assign rx_lbit_cmplt = (rx_lbit_cnt == rx_pre_lbit_time);

  assign rx_bit5_cmplt = rx_bit_cmplt && (rxbit_cnt == `RX_BIT5_NUM);

  // assign decode_bmc   = rx_bmc;
  assign ic_cc_out    = tx_bmc & ucpden;
  assign rxfilt_2n3   = rxfilte[1];
  assign rxfilt_dis   = rxfilte[0];


  /*------------------------------------------------------------------------------
  --  ic_cc_in synchronization to ucpd_clk
  --  Sync the ic_cc_in bus signals to internal ic_clk, ic_cc_in synchronization
  ------------------------------------------------------------------------------*/
  wire asyn_cc_in_a;
  wire asyn_cc_sync;

  assign asyn_cc_in_a = ic_cc_in & ucpden;
  assign cc_in_sync_nxt   = asyn_cc_sync;
  apb_ucpd_bcm41 #(.RST_VAL(1), .VERIF_EN(0)) u_cc_in_icsyzr (
    .clk_d   (ucpd_clk    ),
    .rst_d_n (ic_rst_n    ),
    .init_d_n(1'b1        ),
    .test    (1'b0        ),
    .data_s  (asyn_cc_in_a),
    .data_d  (asyn_cc_sync)
  );

  /*------------------------------------------------------------------------------
  --  ic_cc_in filtering, filter the inputs from the cc bus
  ------------------------------------------------------------------------------*/
  reg [2:0] cc_in_ored;
  reg cc_in_sync_d0;
  reg cc_in_sync_d1;

  always @(*) begin
    cc_in_ored = {cc_in_sync,cc_in_sync_d0,cc_in_sync_d1};
    if(rxfilt_2n3) // Wait for 2 consistent samples before considering it to be a new level
      case(cc_in_ored[2:1])
        2'b00 : cc_data_int_nxt = 1'b0;
        2'b01 : cc_data_int_nxt = 1'b0;
        2'b10 : cc_data_int_nxt = 1'b0;
        2'b11 : cc_data_int_nxt = 1'b1;
      endcase
    else
      case(cc_in_ored)
        3'b000 : cc_data_int_nxt = 1'b0;
        3'b001 : cc_data_int_nxt = 1'b0;
        3'b010 : cc_data_int_nxt = 1'b0;
        3'b011 : cc_data_int_nxt = 1'b0;
        3'b100 : cc_data_int_nxt = 1'b0;
        3'b101 : cc_data_int_nxt = 1'b0;
        3'b110 : cc_data_int_nxt = 1'b0;
        3'b111 : cc_data_int_nxt = 1'b1;
      endcase
  end

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(ic_rst_n == 1'b0) begin
      cc_data_int <= 1'b0;
      cc_in_sync <= 1'b0;
    end
    else begin
      cc_data_int <= cc_data_int_nxt;
      cc_in_sync <= cc_in_sync_nxt;
    end
  end

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(ic_rst_n == 1'b0) begin
      cc_in_sync_d0 <= 1'b0;
      cc_in_sync_d1 <= 1'b0;
    end
    else begin
      cc_in_sync_d0 <= cc_in_sync;
      cc_in_sync_d1 <= cc_in_sync_d0;
    end
  end

  /*------------------------------------------------------------------------------
  --  generator Biphase Mark Coding (BMC) Signaling
  --  biphase mark coding rules:
  --  1. a transition always occurs at the beginning of bit whatever its value is (0 or 1)
  --  2. for logical 1,a transition occurs in the middle of the bit.
  --  3. for logical 0, there is no transiton in the middle of the bit.
  ------------------------------------------------------------------------------*/
  /*------------------------------------------------------------------------------
  --  bmc encode
  ------------------------------------------------------------------------------*/
  always @(posedge ic_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      tx_bmc <= 1'b0;
    else if(bmc_en) begin
      if(tx_bit) begin
        if(hbit_clk_red)
          tx_bmc <= ~tx_bmc;
      end
      else if(bit_clk_red)
        tx_bmc <= ~tx_bmc;
    end
    else
      tx_bmc <= 1'b0;
  end

  /*------------------------------------------------------------------------------
  --  bmc decode
  ------------------------------------------------------------------------------*/
  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      cc_in_d <= 1'b0;
    else
      cc_in_d <= cc_int_nxt; // for generate edg
  end
  assign cc_in_edg = cc_in_d ^ cc_int_nxt;

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      cc_in_vld <= 1'b0;
    else if(rx_sop_en | rx_data_en)
      cc_in_vld <= 1'b0;
    else if(cc_in_edg)
      cc_in_vld <= 1'b1;
  end

  // begin preamble use 2 bit to count edge, get 3 counter
  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      UI_H_cnt <= 11'b0;
    else if(dec_rxbit_en) begin
      UI_H_cnt <= 11'b0;
    end
    else if(cc_in_vld) begin
      if(cc_int)
        UI_H_cnt <= UI_H_cnt+1;
      else
        UI_H_cnt <= 11'b0;
    end
  end

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      UI_L_cnt <= 11'b0;
    else if(dec_rxbit_en) begin
      UI_L_cnt <= 11'b0;
    end
    else if(cc_in_vld) begin
      if(~cc_int)
        UI_L_cnt <= UI_L_cnt+1;
      else
        UI_L_cnt <= 11'b0;
    end
  end

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      simple_cnt     <= 2'b0;
      first_2bit_end <= 1'b0;
    end
    else if(dec_rxbit_en) begin
      simple_cnt     <= 2'b0;
      first_2bit_end <= 1'b0;
    end
    else if(cc_in_vld && cc_in_edg) begin
      if(simple_cnt == 2'd2) begin
        simple_cnt     <= 2'b0;
        first_2bit_end <= 1'b1;
      end
      else
        simple_cnt <= simple_cnt+1;
    end
  end


  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      UI_cntA <= 11'b0;
      UI_cntB <= 11'b0;
      UI_cntC <= 11'b0;
    end
    else if(dec_rxbit_en) begin
      UI_cntA <= 11'b0;
      UI_cntB <= 11'b0;
      UI_cntC <= 11'b0;
    end
    else if(cc_in_vld && cc_in_edg) begin
      case(simple_cnt)
        2'd0 : begin
          if(cc_int)
            UI_cntA <= UI_H_cnt;
          else
            UI_cntA <= UI_L_cnt;
        end
        2'd1 : begin
          if(cc_int)
            UI_cntB <= UI_H_cnt;
          else
            UI_cntB <= UI_L_cnt;
        end
        2'd2 : begin
          if(cc_int)
            UI_cntC <= UI_H_cnt;
          else
            UI_cntC <= UI_L_cnt;
        end
      endcase
    end
  end


  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      UI_ave  <= 11'b0;
      UI_sum  <= 12'b0;
      ave_cnt <= 3'b0;
    end
    else if(training_en && cc_in_edg) begin
      if(ave_cnt == 3'd7 ) begin
        ave_cnt <= 3'b0;
        UI_ave  <= UI_sum >> 3;
        UI_sum  <= 12'b0;
      end
      else begin
        ave_cnt <= ave_cnt + 1;
        UI_sum  <= UI_sum + th_1UI;
      end
    end
    else if(~training_en) begin
      UI_sum  <= 12'b0;
      ave_cnt <= 3'b0;
    end
   if(~receive_en)
      UI_ave  <= 11'b0;
  end

  // wire [19:0] avg_th_1UI;
  // fir_gaussian_lowpass u_fir_gaussian_lowpass (
  //   .clk     (ucpd_clk),
  //   .rst_n   (ic_rst_n),
  //   .data_in (th_1UI),
  //   .data_out(avg_th_1UI)
  //   );

  // according to sum ,to get 1UI for a bit duty at preamble, 1UI = sum/2*3/4
  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      training_en <= 1'b0;
      th_1UI      <= 11'b0;
    end
    else if(dec_rxbit_en) begin
      training_en <= 1'b0;
      th_1UI      <= 11'b0;
    end
    else if(first_2bit_end) begin
      if((UI_cntA < UI_cntC) && (UI_cntB < UI_cntC)) begin
        training_en <= 1'b1;
        th_1UI      <= ((UI_cntA+UI_cntB+UI_cntC)*3)>>3; // (a+b+c)/2*3/4
      end
      else if((UI_cntA > UI_cntB) && (UI_cntA > UI_cntC)) begin
        training_en <= 1'b1;
        th_1UI      <= ((UI_cntA+UI_cntB+UI_cntC)*3)>>3; // (a+b+c)/2*3/4
      end
      else if((UI_cntB > UI_cntC) && (UI_cntB > UI_cntA)) begin // b>c,b>a, standing for lost begin 1
        training_en <= 1'b0;
        th_1UI      <= 11'b0;
      end
    end
  end

  /*------------------------------------------------------------------------------
  --  generate recrice bit
  ------------------------------------------------------------------------------*/
  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      rx_bmc <= 1'b0;
    end
    else if(eop_ok | hrst_vld | crst_vld)
      rx_bmc <= 1'b0;
    else if(cc_in_edg) begin
      if(data_cnt > UI_ave)
        rx_bmc <= 1'b0;
      else if(data1_flag)
        rx_bmc <= 1'b1;
    end
  end

  /*------------------------------------------------------------------------------
  --  decode a bit need counter
  ------------------------------------------------------------------------------*/
  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      data_cnt   <= 11'b0;
      data1_flag <= 1'b0;
    end
    else if(eop_ok) begin
      data_cnt   <= 11'b0;
      data1_flag <= 1'b0;
    end
    else if(~receive_en) begin
      data_cnt   <= 11'b0;
      data1_flag <= 1'b0;
    end
    else if(cc_in_edg) begin
      if(data_cnt <= UI_ave)
        data1_flag <= 1'b1;
      else
        data1_flag <= 1'b0;
      data_cnt <= 11'b0;
    end
    else if(rx_pre_en | rx_sop_en | rx_data_en)
      data_cnt <= data_cnt+1;
  end

  /*------------------------------------------------------------------------------
  --  for decode bmc bit generate poseedge
  ------------------------------------------------------------------------------*/

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      decode_bmc <= 1'b0;
    else
      decode_bmc <= rx_bmc;
  end

  assign pre_rxbit_edg = rx_pre_en & (decode_bmc ^ rx_bmc);

  /*------------------------------------------------------------------------------
  --  calculate receive bit edge counter in preamable, tottle 192
  ------------------------------------------------------------------------------*/

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      pre_rxbit_cnt <= 11'b0;
    else if(rx_pre_cmplt)
      pre_rxbit_cnt <= 11'b0;
    else if(cc_in_vld && cc_in_edg)
      pre_rxbit_cnt <= pre_rxbit_cnt+1;

  end

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      receive_en <= 1'b0;
    else if(training_en)
      receive_en <= 1'b1;
    else if(receive_en & (eop_ok | (hrst_vld | crst_vld)))
      receive_en <= 1'b0;
  end

  /*------------------------------------------------------------------------------
  --  calculate a receive bit time, to get one bit received complete signal
  ------------------------------------------------------------------------------*/

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      rx_pre_hbit_cnt <= 11'b0;
      rx_pre_lbit_cnt <= 11'b0;
    end
    else if(training_en) begin
      if(decode_bmc) begin
        rx_pre_hbit_cnt <= rx_pre_hbit_cnt+1;
        rx_pre_lbit_cnt <= 11'b0;
      end
      else begin
        rx_pre_lbit_cnt <= rx_pre_lbit_cnt+1;
        rx_pre_hbit_cnt <= 11'b0;
      end
    end
  end

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      rx_pre_hbit_time <= 11'b0;
      rx_pre_lbit_time <= 11'b0;
    end
    else if(pre_rxbit_edg) begin
      if(decode_bmc)
        rx_pre_hbit_time <= rx_pre_hbit_cnt;
      else
        rx_pre_lbit_time <= rx_pre_lbit_cnt;
    end
  end

  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n) begin
      rx_hbit_cnt <= 11'b0;
      rx_lbit_cnt <= 11'b0;
    end
    else if(dec_rxbit_en) begin
      if(decode_bmc) begin
        if(rx_hbit_cmplt)
          rx_hbit_cnt <= 11'b0;
        else begin
          rx_hbit_cnt <= rx_hbit_cnt+1;
          rx_lbit_cnt <= 11'b0;
        end
      end
      else begin
        if(rx_lbit_cmplt)
          rx_lbit_cnt <= 11'b0;
        else begin
          rx_lbit_cnt <= rx_lbit_cnt+1;
          rx_hbit_cnt <= 11'b0;
        end
      end
    end
  end

  /*------------------------------------------------------------------------------
  --  detect sop, data, crc, eop half byte(5bits) recive complete
  ------------------------------------------------------------------------------*/
  always @(posedge ucpd_clk or negedge ic_rst_n) begin
    if(~ic_rst_n)
      rxbit_cnt <= 3'b0;
    else if(rx_bit5_cmplt)
      rxbit_cnt <= 3'b0;
    else if(dec_rxbit_en & rx_bit_cmplt)
      rxbit_cnt <= rxbit_cnt+1;
  end



endmodule

// module fir_gaussian_lowpass #(
//   parameter ORDER    = 8    ,
//   parameter SIZE_IN  = 8    ,
//   parameter SIZE_OUT = 20   ,
//   parameter COEF0    = 8'd1 ,
//   parameter COEF1    = 8'd1,
//   parameter COEF2    = 8'd1,
//   parameter COEF3    = 8'd1,
//   parameter COEF4    = 8'd1,
//   parameter COEF5    = 8'd1,
//   parameter COEF6    = 8'd1,
//   parameter COEF7    = 8'd1,
//   parameter COEF8    = 8'd1
// ) (
//   input               clk    , // Clock
//   input               rst_n  , // Asynchronous reset active low
//   input [SIZE_IN-1:0] data_in,
//   output reg [SIZE_OUT-1:0] data_out
// );

//   reg [SIZE_IN-1:0] samples[1:ORDER];
//   integer           k               ;
//   wire [SIZE_OUT-1:0] data_out_nxt  ;

//   assign data_out_nxt = COEF0*data_in + COEF1*samples[1] + COEF2*samples[2]
//                                       + COEF3*samples[3] + COEF4*samples[4]
//                                       + COEF5*samples[5] + COEF6*samples[6]
//                                       + COEF7*samples[7] + COEF8*samples[8];

//   always @(posedge clk or negedge rst_n) begin
//     if(~rst_n)
//       data_out <= 20'b0;
//     else
//       data_out <= data_out_nxt>>3;
//   end

//   always @(posedge clk or negedge rst_n) begin
//     if(~rst_n) begin
//       for(k=1; k<= ORDER; k=k+1)
//         samples[k] <= 0;
//     end
//     else begin
//       samples[1] <= data_in;
//       for(k=2; k<= ORDER; k=k+1)
//         samples[k] <= samples[k-1];
//     end
//   end
// endmodule



















