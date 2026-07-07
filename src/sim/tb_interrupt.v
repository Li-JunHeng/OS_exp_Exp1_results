`timescale 1ns / 1ps

module tb_interrupt;
    localparam [31:0] NOP = 32'h0000_0013;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg external_irq = 1'b0;
    reg [4:0] reg_sel = 5'd10;

    wire mem_w;
    wire [31:0] pc;
    wire [31:0] addr_out;
    wire [31:0] data_out;
    wire [2:0] dm_ctrl;
    wire [31:0] reg_data;

    reg [31:0] imem [0:255];
    wire [31:0] inst = imem[pc[9:2]];

    integer i;
    integer cycle;
    reg saw_vector;

    SCPU U_SCPU(
        .clk(clk),
        .reset(reset),
        .software_irq(1'b0),
        .timer_irq(1'b0),
        .external_irq(external_irq),
        .uart_irq(1'b0),
        .gpio_irq(1'b0),
        .spi_irq(1'b0),
        .i2c_irq(1'b0),
        .inst_in(inst),
        .Data_in(32'b0),
        .mem_w(mem_w),
        .PC_out(pc),
        .Addr_out(addr_out),
        .Data_out(data_out),
        .dm_ctrl(dm_ctrl),
        .reg_sel(reg_sel),
        .reg_data(reg_data)
    );

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            imem[i] = NOP;
        end

        imem[10'h000] = 32'h0010_0093; // addi x1, x0, 1
        imem[10'h001] = 32'h0020_0113; // addi x2, x0, 2
        imem[10'h002] = 32'h0030_0193; // addi x3, x0, 3
        imem[10'h003] = 32'h0040_0213; // addi x4, x0, 4
        imem[10'h020] = 32'h0550_0513; // 0x80: addi x10, x0, 0x55
        imem[10'h021] = 32'h3020_0073; // 0x84: mret

        saw_vector = 1'b0;

        repeat (4) @(posedge clk);
        reset = 1'b0;

        repeat (5) @(posedge clk);
        external_irq = 1'b1;
        repeat (3) @(posedge clk);
        external_irq = 1'b0;

        for (cycle = 0; cycle < 120; cycle = cycle + 1) begin
            @(posedge clk);
            if (pc == 32'h0000_0080) begin
                saw_vector = 1'b1;
            end

            if (saw_vector && pc < 32'h0000_0080 && reg_data == 32'h0000_0055) begin
                $display("PASS: interrupt vector executed and mret returned, pc=%h x10=%h", pc, reg_data);
                $finish;
            end
        end

        $fatal(1, "FAIL: interrupt did not vector, execute ISR, and return. pc=%h x10=%h", pc, reg_data);
    end
endmodule
