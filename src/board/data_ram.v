`timescale 1ns / 1ps

module data_ram(
    input         clk,
    input  [3:0]  we,
    input  [9:0]  addr,
    input  [31:0] din,
    output [31:0] dout
);
    reg [31:0] ram[0:1023];

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            ram[i] = 32'b0;
        $readmemh("memory/D_mem.dat", ram, 0, 42);
    end

    always @(posedge clk) begin
        if (we[0]) ram[addr][7:0] <= din[7:0];
        if (we[1]) ram[addr][15:8] <= din[15:8];
        if (we[2]) ram[addr][23:16] <= din[23:16];
        if (we[3]) ram[addr][31:24] <= din[31:24];
    end

    assign dout = ram[addr];
endmodule
