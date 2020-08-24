
/*
------------------------------------------------------------------------
--
-- File :                       apb_ucpd_biu.v
-- Author:                      luo kun
-- Date :                       $Date: 2020/07/12 $
// Abstract: Apb bus interface module.
//           This module is intended for use with APB slave
//           macrocells.  The module generates output signals
//           from the APB bus interface that are intended for use in
//           the register block of the macrocell.
//
//        1: Generates the write enable (wr_en) and read
//           enable (rd_en) for register accesses to the macrocell.
//
//        2: Decodes the address bus (paddr) to generate the active
//           byte lane signal (byte_en).
//
//        3: Strips the APB address bus (paddr) to generate the
//           register offset address output (reg_addr).
//
//        4: Registers APB read data (prdata) onto the APB data bus.
//           The read data is routed to the correct byte lane in this
//           module.
--
--
-- Modification History:
-- Date                 By      Version Change  Description
-- =====================================================================
-- See CVS log
-- =====================================================================
*/
module apb_ucpd_biu (
   input             pclk    , // APB clock
   input             presetn , // APB reset
   input             psel    , // APB slave select
   input             pwrite  , // APB write/read
   input             penable , // APB enable
   input      [ 7:0] paddr   , // APB address
   input      [31:0] pwdata  , // APB write data bus
   input      [31:0] iprdata , // Internal read data bus
   output            wr_en   , // Write enable signal
   output            rd_en   , // Read enable signal
   output reg [ 3:0] byte_en , // Active byte lane signal
   output     [ 5:0] reg_addr, // Register address offset
   output reg [31:0] ipwdata , // Internal write data bus
   output reg [31:0] prdata    // APB read data bus
);

   // --------------------------------------------
   // -- write/read enable
   //
   // -- Generate write/read enable signals from
   // -- psel, penable and pwrite inputs
   // --------------------------------------------
   assign wr_en = psel &  penable &  pwrite;
   assign rd_en = psel & (!penable) & (!pwrite);
   // --------------------------------------------
   // -- Register address
   //
   // -- Strips register offset address from the
   // -- APB address bus
   // --------------------------------------------
   assign reg_addr = paddr[7:2];

   // --------------------------------------------
   // -- APB write data
   //
   // -- ipwdata is zero padded before being
   // -- passed through this block
   // --------------------------------------------
   always @(pwdata) begin : IPWDATA_PROC
      ipwdata = 32'b0;
      ipwdata = pwdata;
   end

   // --------------------------------------------
   // -- Set active byte lane
   //
   // -- This bit vector is used to set the active
   // -- byte lanes for write/read accesses to the
   // -- registers
   // --------------------------------------------
   always @(paddr) begin : BYTE_EN_PROC
      byte_en = 4'b1111;
   end

   // --------------------------------------------
   // -- APB read data.
   //
   // -- Register data enters this block on a
   // -- 32-bit bus (iprdata). The upper unused
   // -- bit(s) have been zero padded before entering
   // -- this block.  The process below strips the
   // -- active byte lane(s) from the 32-bit bus
   // -- and registers the data out to the APB
   // -- read data bus (prdata).
   // --------------------------------------------
   always @(posedge pclk or negedge presetn) begin : PRDATA_PROC
      if(presetn == 1'b0)
         prdata <= 32'b0;
      else if(rd_en)
         prdata <= iprdata;
   end

endmodule // apb_i2c_biu

