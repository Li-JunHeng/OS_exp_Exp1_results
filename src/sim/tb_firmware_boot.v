`timescale 1ns / 1ps

module tb_firmware_boot;
    reg clk = 1'b0;
    reg reset = 1'b1;

    wire mem_r;
    wire mem_w;
    wire [31:0] pc;
    wire [31:0] addr_out;
    wire [31:0] data_out;
    wire [2:0] dm_ctrl;
    wire [31:0] data_in;
    wire [31:0] data_write_to_dm;
    wire [3:0] wea_mem;

    reg [31:0] imem [0:4095];
    reg [31:0] dmem [0:1023];
    reg [31:0] vga_regs [0:4095];
    reg [31:0] display_value;
    reg vblank_irq;
    reg saw_vga;
    reg saw_display;
    integer display_writes;
    integer i;
    integer cycle;

    wire [31:0] inst = imem[pc[13:2]];
    wire data_is_vga = (addr_out[31:16] == 16'hc000);
    wire data_is_display = (addr_out == 32'he0000000);
    wire data_is_ram = (addr_out[31:12] == 20'h00000);

    assign data_in =
        data_is_vga ? vga_regs[addr_out[13:2]] :
        data_is_display ? display_value :
        data_is_ram ? dmem[addr_out[11:2]] :
        32'b0;

    SCPU #(
        .RESET_MSTATUS(32'h0000_0000),
        .RESET_MIE(32'h0000_0000),
        .RESET_MTVEC(32'h0000_0000)
    ) U_SCPU(
        .clk(clk),
        .reset(reset),
        .software_irq(1'b0),
        .timer_irq(vblank_irq),
        .external_irq(1'b0),
        .uart_irq(1'b0),
        .gpio_irq(1'b0),
        .spi_irq(1'b0),
        .i2c_irq(1'b0),
        .keyboard_irq(1'b0),
        .inst_in(inst),
        .Data_in(data_in),
        .mem_r(mem_r),
        .mem_w(mem_w),
        .PC_out(pc),
        .Addr_out(addr_out),
        .Data_out(data_out),
        .dm_ctrl(dm_ctrl),
        .reg_sel(5'b0),
        .reg_data()
    );

    dm_controller U_DM_CONTROLLER(
        .mem_w(mem_w),
        .Addr_in(addr_out),
        .Data_write(data_out),
        .dm_ctrl(dm_ctrl),
        .Data_read_from_dm(data_in),
        .Data_read(),
        .Data_write_to_dm(data_write_to_dm),
        .wea_mem(wea_mem)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            display_value <= 32'hffff_ffff;
            saw_vga <= 1'b0;
            saw_display <= 1'b0;
            display_writes <= 0;
            vblank_irq <= 1'b0;
            for (i = 0; i < 4096; i = i + 1) begin
                vga_regs[i] <= 32'b0;
            end
        end else begin
            if (cycle == 2000) begin
                vblank_irq <= 1'b1;
                vga_regs[(32'hc0000004 >> 2) & 4095] <= 32'h0000_0001;
            end
            if (cycle == 5000) begin
                vblank_irq <= 1'b1;
                vga_regs[(32'hc0000004 >> 2) & 4095] <= 32'h0000_0001;
            end
            if (mem_w && addr_out == 32'hc0000004 && data_write_to_dm[0]) begin
                vblank_irq <= 1'b0;
                vga_regs[(32'hc0000004 >> 2) & 4095] <= 32'h0000_0000;
            end

            if (mem_w && data_is_ram) begin
                if (wea_mem[0]) dmem[addr_out[11:2]][7:0] <= data_write_to_dm[7:0];
                if (wea_mem[1]) dmem[addr_out[11:2]][15:8] <= data_write_to_dm[15:8];
                if (wea_mem[2]) dmem[addr_out[11:2]][23:16] <= data_write_to_dm[23:16];
                if (wea_mem[3]) dmem[addr_out[11:2]][31:24] <= data_write_to_dm[31:24];
            end
            if (mem_w && data_is_vga) begin
                vga_regs[addr_out[13:2]] <= data_write_to_dm;
                saw_vga <= 1'b1;
            end
            if (mem_w && data_is_display) begin
                display_value <= data_write_to_dm;
                saw_display <= 1'b1;
                display_writes <= display_writes + 1;
            end
        end
    end

    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            imem[i] = 32'b0;
        end
        for (i = 0; i < 1024; i = i + 1) begin
            dmem[i] = 32'b0;
        end
        $readmemh("E:/Vivado/OS_Exp_1/memory/testac.dat", imem);
        $readmemh("E:/Vivado/OS_Exp_1/memory/D_mem.dat", dmem);

        repeat (8) @(posedge clk);
        reset = 1'b0;

        for (cycle = 0; cycle < 100000; cycle = cycle + 1) begin
            @(posedge clk);
            if (saw_vga && saw_display && display_writes >= 2) begin
                $display("PASS: firmware wrote VGA/display MMIO across VBlank frames, display=%h pc=%h writes=%0d",
                         display_value, pc, display_writes);
                $finish;
            end
        end

        $fatal(1, "FAIL: firmware did not write expected MMIO, saw_vga=%b saw_display=%b display=%h pc=%h mcause=%h mtval=%h",
               saw_vga, saw_display, display_value, pc, U_SCPU.csr_mcause, U_SCPU.csr_mtval);
    end
endmodule
