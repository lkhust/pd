
module apb_ucpd_clk_div (
  input        clk_in ,
  input        rst_n  ,
  input  [6:0] divisor, // 分频常数
  output       clk_out
);

  //上升沿和下降沿生成的分频时钟，占空比为（divisor>>1）/divisor，相或操作后可以得到占空比50%的奇分频
  reg        clk_p,clk_n;
  reg        clk_even; //偶分频时钟
  reg  [6:0] cnt     ;
  wire       odd     ;

  assign odd = divisor[0] & 1'b1; //奇数odd判断

  always @(posedge clk_in or negedge rst_n)
    if (!rst_n)
      cnt <= 7'd0;
    else if(cnt >= (divisor - 1))
      cnt <= 7'd0;
    else
      cnt <= cnt + 1'b1;

  //奇分频
  always @( posedge clk_in or negedge rst_n)
    if (!rst_n )
      clk_p <= 1'b0;
    else if(cnt == 7'd0)
      clk_p <= 1'b1;
    else if(cnt == (divisor >> 1))
      clk_p <= 1'b0;

  always @(negedge clk_in or negedge rst_n)
    if (!rst_n )
      clk_n <= 1'b0;
    else if(cnt == 7'd0)
      clk_n <= 1'b1;
    else if(cnt == (divisor >> 1))
      clk_n <= 1'b0;

  //偶分频
  always @(posedge clk_in or negedge rst_n)
    if (!rst_n )
      clk_even <= 1'b0;
    else if(cnt == 7'd0)
      clk_even <= 1'b1;
    else if(cnt == (divisor >> 1))
      clk_even <= 1'b0;

  assign clk_out = (odd) ? (clk_p | clk_n) : clk_even;

endmodule
