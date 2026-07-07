`timescale 1ns / 1ps

module tb_traps;
    localparam [31:0] NOP = 32'h0000_0013;

    localparam [31:0] CAUSE_INST_ACCESS_FAULT = 32'd1;
    localparam [31:0] CAUSE_ILLEGAL_INST      = 32'd2;
    localparam [31:0] CAUSE_BREAKPOINT        = 32'd3;
    localparam [31:0] CAUSE_LOAD_ACCESS_FAULT = 32'd5;
    localparam [31:0] CAUSE_STORE_ACCESS_FAULT = 32'd7;
    localparam [31:0] CAUSE_ECALL_M           = 32'd11;
    localparam [31:0] CAUSE_MSI               = 32'h8000_0003;
    localparam [31:0] CAUSE_MTI               = 32'h8000_0007;
    localparam [31:0] CAUSE_MEI               = 32'h8000_000b;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg software_irq = 1'b0;
    reg timer_irq = 1'b0;
    reg external_irq = 1'b0;
    reg [4:0] reg_sel = 5'b0;

    wire mem_w;
    wire [31:0] pc;
    wire [31:0] addr_out;
    wire [31:0] data_out;
    wire [2:0] dm_ctrl;
    wire [31:0] reg_data;

    reg [31:0] imem [0:1023];
    wire [31:0] inst = imem[pc[11:2]];

    integer i;
    reg saw_mem_w;

    SCPU U_SCPU(
        .clk(clk),
        .reset(reset),
        .software_irq(software_irq),
        .timer_irq(timer_irq),
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

    always @(posedge clk) begin
        if (reset) begin
            saw_mem_w <= 1'b0;
        end else if (mem_w) begin
            saw_mem_w <= 1'b1;
        end
    end

    task clear_imem;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                imem[i] = NOP;
            end
            imem[10'h020] = NOP;
        end
    endtask

    task reset_cpu;
        begin
            software_irq = 1'b0;
            timer_irq = 1'b0;
            external_irq = 1'b0;
            reset = 1'b1;
            repeat (4) @(posedge clk);
            reset = 1'b0;
            @(posedge clk);
        end
    endtask

    task wait_trap;
        input [31:0] expected_cause;
        input [31:0] expected_mepc;
        input [31:0] expected_mtval;
        input        check_mepc;
        input        check_mtval;
        integer cycle;
        reg found;
        begin
            found = 1'b0;
            begin : wait_loop
                for (cycle = 0; cycle < 120; cycle = cycle + 1) begin
                    @(posedge clk);
                    if (pc == 32'h0000_0080 && U_SCPU.csr_mcause == expected_cause) begin
                        found = 1'b1;
                        disable wait_loop;
                    end
                end
            end

            if (!found) begin
                $fatal(1, "trap cause mismatch: expected=%h actual=%h pc=%h",
                       expected_cause, U_SCPU.csr_mcause, pc);
            end
            if (check_mepc && U_SCPU.csr_mepc != expected_mepc) begin
                $fatal(1, "mepc mismatch: expected=%h actual=%h cause=%h",
                       expected_mepc, U_SCPU.csr_mepc, U_SCPU.csr_mcause);
            end
            if (check_mtval && U_SCPU.csr_mtval != expected_mtval) begin
                $fatal(1, "mtval mismatch: expected=%h actual=%h cause=%h",
                       expected_mtval, U_SCPU.csr_mtval, U_SCPU.csr_mcause);
            end
        end
    endtask

    initial begin
        clear_imem();

        reset_cpu();
        software_irq = 1'b1;
        wait_trap(CAUSE_MSI, 32'b0, 32'b0, 1'b0, 1'b1);
        software_irq = 1'b0;

        reset_cpu();
        timer_irq = 1'b1;
        wait_trap(CAUSE_MTI, 32'b0, 32'b0, 1'b0, 1'b1);
        timer_irq = 1'b0;

        reset_cpu();
        external_irq = 1'b1;
        wait_trap(CAUSE_MEI, 32'b0, 32'b0, 1'b0, 1'b1);
        external_irq = 1'b0;

        clear_imem();
        imem[10'h000] = 32'h0000_0000;
        reset_cpu();
        wait_trap(CAUSE_ILLEGAL_INST, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b1);

        clear_imem();
        imem[10'h000] = 32'h0010_0073;
        reset_cpu();
        wait_trap(CAUSE_BREAKPOINT, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b1);

        clear_imem();
        imem[10'h000] = 32'h0000_0073;
        reset_cpu();
        wait_trap(CAUSE_ECALL_M, 32'h0000_0000, 32'h0000_0000, 1'b1, 1'b1);

        clear_imem();
        imem[10'h000] = 32'h0000_106f; // jal x0, 0x1000
        reset_cpu();
        wait_trap(CAUSE_INST_ACCESS_FAULT, 32'h0000_1000, 32'h0000_1000, 1'b1, 1'b1);

        clear_imem();
        imem[10'h000] = 32'h1000_00b7; // lui x1, 0x10000
        imem[10'h001] = 32'h0000_a103; // lw x2, 0(x1)
        reset_cpu();
        wait_trap(CAUSE_LOAD_ACCESS_FAULT, 32'h0000_0004, 32'h1000_0000, 1'b1, 1'b1);

        clear_imem();
        imem[10'h000] = 32'h1000_00b7; // lui x1, 0x10000
        imem[10'h001] = 32'h0020_a023; // sw x2, 0(x1)
        reset_cpu();
        wait_trap(CAUSE_STORE_ACCESS_FAULT, 32'h0000_0004, 32'h1000_0000, 1'b1, 1'b1);
        if (saw_mem_w) begin
            $fatal(1, "store access fault still asserted mem_w");
        end

        $display("PASS: machine interrupts and required synchronous traps were handled");
        $finish;
    end
endmodule
