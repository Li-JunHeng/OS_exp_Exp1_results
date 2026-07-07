`timescale 1ns / 1ps

// instruction memory
module im(input  [8:2]  addr,
            output [31:0] dout );

  reg  [31:0] ROM[0:127];

  initial
    $readmemh("memory/Test_37_Instr8.dat", ROM, 0, 70);

  assign dout = ROM[addr]; // word aligned
endmodule  
