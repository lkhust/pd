/*
------------------------------------------------------------------------
--
-- File :                       apb_ucpd_bcm41.v
-- Author:                      luo kun
-- Date :                       $Date: 2019/09/19 $
-- Abstract     :               Verilog module for DWbb
--
--
-- Modification History:
-- Date                 By      Version Change  Description
-- =====================================================================
-- See CVS log
-- =====================================================================
*/
module apb_ucpd_bcm41 (
  clk_d,
  rst_d_n,
  init_d_n,
  data_s,
  test,
  data_d
);

parameter WIDTH       = 1 ; // RANGE 1 to 1024
parameter RST_VAL     = -1; // RANGE -1 to 2147483647
parameter F_SYNC_TYPE = 2 ; // RANGE 0 to 4
parameter TST_MODE    = 0 ; // RANGE 0 to 2
parameter VERIF_EN    = 1 ; // RANGE 0 to 5
parameter SVA_TYPE    = 1 ; // RANGE 0 to 2

// spyglass disable_block ParamWidthMismatch-ML
// SMD: Parameter width does not match with the value assigned
// SJ: Although there is mismatch between parameters, the legal value of RHS parameter can not exceed the range that the LHS parameter can represent. In regards to SpyGlass complaining about LHS not equal RHS when assigning a sized localparam to a value calculated from parameters (which are most likely considered 32-bit signed integers), the messages around this type of assignment could be turned off.
// spyglass disable_block W163
// SMD: Truncation of bits in constant integer conversion
// SJ: The W163 rule flags constant integer assignments to signals when the width of the signal is narrower than the width of the constant integer. When assigning a constant integer value to a LHS operand, the width specification for RHS should match LHS operand width. If the signal is wider than the constant integer, the extra bits are padded with zeros. If the signal is narrower than the constant integer, the extra high-order non-zero bits are discarded.
localparam [WIDTH-1 : 0] RST_POLARITY = RST_VAL;
// spyglass enable_block ParamWidthMismatch-ML
// spyglass enable_block W163

input              clk_d   ; // clock input from destination domain
input              rst_d_n ; // active low asynchronous reset from destination domain
input              init_d_n; // active low synchronous reset from destination domain
input  [WIDTH-1:0] data_s  ; // data to be synchronized from source domain
input              test    ; // test input
output [WIDTH-1:0] data_d  ; // data synchronized to destination domain

wire [WIDTH-1:0] data_s_int;
wire [WIDTH-1:0] data_d_int;

  assign data_s_int = data_s ^ RST_POLARITY;

  apb_ucpd_bcm21 #(WIDTH,F_SYNC_TYPE+8,TST_MODE,VERIF_EN,SVA_TYPE) U_SYNC (
    .clk_d   (clk_d     ),
    .rst_d_n (rst_d_n   ),
    .init_d_n(init_d_n  ),
    .data_s  (data_s_int),
    .test    (test      ),
    .data_d  (data_d_int)
  );

  assign data_d = data_d_int ^ RST_POLARITY;

endmodule
