`timescale 1ns / 1ps

module tb_jal_boot;
    reg clk = 1'b0;
    reg reset = 1'b1;
    wire [31:0] pc;
    wire [31:0] inst;

    reg [31:0] imem [0:255];
    integer i;
    integer cycle;

    assign inst = imem[pc[9:2]];

    SCPU U_SCPU(
        .clk(clk),
        .reset(reset),
        .software_irq(1'b0),
        .timer_irq(1'b0),
        .external_irq(1'b0),
        .uart_irq(1'b0),
        .gpio_irq(1'b0),
        .spi_irq(1'b0),
        .i2c_irq(1'b0),
        .keyboard_irq(1'b0),
        .inst_in(inst),
        .Data_in(32'b0),
        .mem_r(),
        .mem_w(),
        .PC_out(pc),
        .Addr_out(),
        .Data_out(),
        .dm_ctrl(),
        .reg_sel(5'b0),
        .reg_data()
    );

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            imem[i] = 32'h00000013;
        end
        imem[0] = 32'h0100006f; // jal x0, 0x10

        repeat (4) @(posedge clk);
        reset = 1'b0;

        for (cycle = 0; cycle < 20; cycle = cycle + 1) begin
            @(posedge clk);
            if (pc == 32'h10) begin
                $display("PASS: jal reached target");
                $finish;
            end
        end
        $fatal(1, "FAIL: jal did not reach target, pc=%h", pc);
    end
endmodule
