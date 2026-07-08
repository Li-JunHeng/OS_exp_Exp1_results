`timescale 1ns / 1ps

// instruction memory
module im(input  [13:2] addr,
            output [31:0] dout );

  reg  [31:0] ROM[0:4095];

  integer i;
  initial begin
    for (i = 0; i < 4096; i = i + 1)
      ROM[i] = 32'b0;
    $readmemh("E:/Vivado/OS_Exp_1/memory/testac.dat", ROM);
  end

  assign dout = ROM[addr]; // word aligned
endmodule  
