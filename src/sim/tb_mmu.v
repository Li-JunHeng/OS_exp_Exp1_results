`timescale 1ns / 1ps

module tb_mmu;
    localparam [31:0] NOP = 32'h0000_0013;

    localparam [31:0] CAUSE_INST_PAGE_FAULT  = 32'd12;
    localparam [31:0] CAUSE_LOAD_PAGE_FAULT  = 32'd13;
    localparam [31:0] CAUSE_STORE_PAGE_FAULT = 32'd15;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg [31:0] data_in = 32'hcafe_babe;
    reg [4:0] reg_sel = 5'd0;

    wire mem_w;
    wire [31:0] pc;
    wire [31:0] addr_out;
    wire [31:0] data_out;
    wire [2:0] dm_ctrl;
    wire [31:0] reg_data;

    reg [31:0] imem [0:1023];
    wire [31:0] inst = imem[pc[11:2]];

    integer i;
    reg saw_load_phys_zero;
    reg saw_store_phys_zero;
    reg saw_any_store;

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
        .Data_in(data_in),
        .mem_r(),
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
            saw_load_phys_zero <= 1'b0;
            saw_store_phys_zero <= 1'b0;
            saw_any_store <= 1'b0;
        end else begin
            if (U_SCPU.ex_mem_valid && U_SCPU.ex_mem_wdsel == 2'b01 && addr_out == 32'b0) begin
                saw_load_phys_zero <= 1'b1;
            end
            if (mem_w) begin
                saw_any_store <= 1'b1;
                if (addr_out == 32'b0 && data_out == 32'h0000_005a) begin
                    saw_store_phys_zero <= 1'b1;
                end
            end
        end
    end

    task clear_imem;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                imem[i] = NOP;
            end
            imem[10'h020] = NOP; // mtvec = 0x80
        end
    endtask

    task reset_cpu;
        begin
            reset = 1'b1;
            repeat (4) @(posedge clk);
            reset = 1'b0;
            U_SCPU.csr_satp = 32'h8000_0000;
            U_SCPU.tlb_vpn[0] = 20'h00000;
            U_SCPU.tlb_ppn[0] = 20'h00000;
            U_SCPU.tlb_valid[0] = 1'b1;
            U_SCPU.tlb_read[0] = 1'b1;
            U_SCPU.tlb_write[0] = 1'b1;
            U_SCPU.tlb_exec[0] = 1'b1;
            @(posedge clk);
        end
    endtask

    task reset_cpu_plain;
        begin
            reset = 1'b1;
            repeat (4) @(posedge clk);
            reset = 1'b0;
            @(posedge clk);
        end
    endtask

    task map_tlb1;
        input read_perm;
        input write_perm;
        input exec_perm;
        begin
            U_SCPU.tlb_vpn[1] = 20'h00001;
            U_SCPU.tlb_ppn[1] = 20'h00000;
            U_SCPU.tlb_valid[1] = 1'b1;
            U_SCPU.tlb_read[1] = read_perm;
            U_SCPU.tlb_write[1] = write_perm;
            U_SCPU.tlb_exec[1] = exec_perm;
        end
    endtask

    task wait_trap;
        input [31:0] expected_cause;
        input [31:0] expected_mepc;
        input [31:0] expected_mtval;
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
                $fatal(1, "page trap mismatch: expected=%h actual=%h pc=%h",
                       expected_cause, U_SCPU.csr_mcause, pc);
            end
            if (U_SCPU.csr_mepc != expected_mepc) begin
                $fatal(1, "page mepc mismatch: expected=%h actual=%h cause=%h",
                       expected_mepc, U_SCPU.csr_mepc, U_SCPU.csr_mcause);
            end
            if (U_SCPU.csr_mtval != expected_mtval) begin
                $fatal(1, "page mtval mismatch: expected=%h actual=%h cause=%h",
                       expected_mtval, U_SCPU.csr_mtval, U_SCPU.csr_mcause);
            end
        end
    endtask

    initial begin
        clear_imem();
        imem[10'h000] = 32'h00f0_0093; // addi x1, x0, 15
        imem[10'h001] = 32'h7c00_1073; // csrrw x0, tlbidx, x0
        imem[10'h002] = NOP;
        imem[10'h003] = NOP;
        imem[10'h004] = NOP;
        imem[10'h005] = 32'h7c10_1073; // csrrw x0, tlbvpn, x0
        imem[10'h006] = 32'h7c20_1073; // csrrw x0, tlbppn, x0
        imem[10'h007] = 32'h7c30_9073; // csrrw x0, tlbflags, x1
        imem[10'h008] = 32'h0010_0113; // addi x2, x0, 1
        imem[10'h009] = NOP;
        imem[10'h00a] = NOP;
        imem[10'h00b] = NOP;
        imem[10'h00c] = 32'h7c01_1073; // csrrw x0, tlbidx, x2
        imem[10'h00d] = NOP;
        imem[10'h00e] = NOP;
        imem[10'h00f] = NOP;
        imem[10'h010] = 32'h7c11_1073; // csrrw x0, tlbvpn, x2
        imem[10'h011] = 32'h7c20_1073; // csrrw x0, tlbppn, x0
        imem[10'h012] = 32'h0030_0193; // addi x3, x0, 3
        imem[10'h013] = NOP;
        imem[10'h014] = NOP;
        imem[10'h015] = NOP;
        imem[10'h016] = 32'h7c31_9073; // csrrw x0, tlbflags, x3
        imem[10'h017] = 32'h8000_0237; // lui x4, 0x80000
        imem[10'h018] = NOP;
        imem[10'h019] = NOP;
        imem[10'h01a] = NOP;
        imem[10'h01b] = 32'h1802_1073; // csrrw x0, satp, x4
        imem[10'h01c] = NOP;
        imem[10'h01d] = NOP;
        imem[10'h01e] = NOP;
        imem[10'h01f] = 32'h0000_12b7; // lui x5, 0x1
        imem[10'h020] = 32'h0002_a303; // lw x6, 0(x5)
        reg_sel = 5'd6;
        data_in = 32'hfeed_face;
        reset_cpu_plain();
        repeat (80) @(posedge clk);
        if (!saw_load_phys_zero || reg_data != 32'hfeed_face) begin
            $fatal(1, "CSR-configured TLB load failed: saw=%b x6=%h satp=%h",
                   saw_load_phys_zero, reg_data, U_SCPU.csr_satp);
        end

        clear_imem();
        imem[10'h000] = 32'h0000_10b7; // lui x1, 0x1
        imem[10'h001] = 32'h0000_a103; // lw x2, 0(x1)
        imem[10'h002] = 32'h07a0_0193; // addi x3, x0, 0x7a
        reg_sel = 5'd2;
        data_in = 32'hcafe_babe;
        reset_cpu();
        map_tlb1(1'b1, 1'b0, 1'b0);
        repeat (20) @(posedge clk);
        if (!saw_load_phys_zero || reg_data != 32'hcafe_babe) begin
            $fatal(1, "load translation failed: saw=%b x2=%h addr=%h",
                   saw_load_phys_zero, reg_data, addr_out);
        end

        clear_imem();
        imem[10'h000] = 32'h0000_10b7; // lui x1, 0x1
        imem[10'h001] = 32'h05a0_0113; // addi x2, x0, 0x5a
        imem[10'h002] = 32'h0020_a023; // sw x2, 0(x1)
        reset_cpu();
        map_tlb1(1'b0, 1'b1, 1'b0);
        repeat (24) @(posedge clk);
        if (!saw_store_phys_zero) begin
            $fatal(1, "store translation failed: mem_w=%b addr=%h data=%h",
                   mem_w, addr_out, data_out);
        end

        clear_imem();
        imem[10'h000] = 32'h0000_106f; // jal x0, 0x1000
        reset_cpu();
        wait_trap(CAUSE_INST_PAGE_FAULT, 32'h0000_1000, 32'h0000_1000);

        clear_imem();
        imem[10'h000] = 32'h0000_10b7; // lui x1, 0x1
        imem[10'h001] = 32'h0000_a103; // lw x2, 0(x1)
        reset_cpu();
        wait_trap(CAUSE_LOAD_PAGE_FAULT, 32'h0000_0004, 32'h0000_1000);

        clear_imem();
        imem[10'h000] = 32'h0000_10b7; // lui x1, 0x1
        imem[10'h001] = 32'h05a0_0113; // addi x2, x0, 0x5a
        imem[10'h002] = 32'h0020_a023; // sw x2, 0(x1)
        reset_cpu();
        map_tlb1(1'b1, 1'b0, 1'b0);
        repeat (2) @(posedge clk);
        saw_any_store = 1'b0;
        wait_trap(CAUSE_STORE_PAGE_FAULT, 32'h0000_0008, 32'h0000_1000);
        if (saw_any_store) begin
            $fatal(1, "store page fault still asserted mem_w");
        end

        $display("PASS: simplified MMU, TLB translation, and page faults worked");
        $finish;
    end
endmodule
