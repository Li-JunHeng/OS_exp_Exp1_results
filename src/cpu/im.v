`timescale 1ns / 1ps

// instruction memory
module im(input  [11:2] addr,
            output [31:0] dout );

  reg  [31:0] ROM[0:1023];

  integer i;
  initial begin
    for (i = 0; i < 1024; i = i + 1)
      ROM[i] = 32'b0;
    $readmemh("E:/Vivado/OS_Exp_1/memory/testac.dat", ROM);
  end

  assign dout = ROM[addr]; // word aligned
endmodule  
