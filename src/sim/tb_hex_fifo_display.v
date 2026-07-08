`timescale 1ns / 1ps

module tb_hex_fifo_display;
    localparam [31:0] DISPLAY_ADDR = 32'he0000000;
    localparam [31:0] PS2_DATA_ADDR = 32'hd0000000;
    localparam [31:0] PS2_STATUS_ADDR = 32'hd0000004;

    reg clk = 1'b0;
    reg reset = 1'b1;

    wire mem_r;
    wire mem_w;
    wire [31:0] pc;
    wire [31:0] addr_out;
    wire [31:0] data_out;
    wire [2:0] dm_ctrl;
    wire [31:0] data_in;

    reg [31:0] imem [0:1023];
    wire [31:0] inst = imem[pc[11:2]];

    reg [7:0] scan_queue [0:15];
    integer scan_idx;
    integer scan_count;
    integer cycle;
    reg [31:0] last_display;

    assign data_in =
        (addr_out == PS2_STATUS_ADDR) ? ((scan_idx < scan_count) ? 32'h00000001 : 32'h00000000) :
        (addr_out == PS2_DATA_ADDR)   ? {24'b0, scan_queue[scan_idx]} :
                                        32'h00000000;

    SCPU #(
        .RESET_MSTATUS(32'h0000_0000),
        .RESET_MIE(32'h0000_0000),
        .RESET_MTVEC(32'h0000_0000)
    ) U_SCPU(
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
        .mem_r(mem_r),
        .mem_w(mem_w),
        .PC_out(pc),
        .Addr_out(addr_out),
        .Data_out(data_out),
        .dm_ctrl(dm_ctrl),
        .reg_sel(5'b0),
        .reg_data()
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            scan_idx <= 0;
            last_display <= 32'hffff_ffff;
        end else begin
            if (mem_r && addr_out == PS2_DATA_ADDR && scan_idx < scan_count) begin
                scan_idx <= scan_idx + 1;
            end
            if (mem_w && addr_out == DISPLAY_ADDR) begin
                last_display <= data_out;
            end
        end
    end

    initial begin
        $readmemh("E:/Vivado/OS_Exp_1/memory/testac.dat", imem);

        // Mixed valid and invalid Set-2 scan codes:
        // invalid, 1, A, F0 break prefix, F, invalid, 0, 9, 2, 3, 4, 5, 6.
        // Accepted sequence is 1 A F 0 9 2 3 4 5 6, so the 8-deep display FIFO
        // must end at F0923456.
        scan_queue[0] = 8'h1d;
        scan_queue[1] = 8'h16;
        scan_queue[2] = 8'h1c;
        scan_queue[3] = 8'hf0;
        scan_queue[4] = 8'h2b;
        scan_queue[5] = 8'h29;
        scan_queue[6] = 8'h45;
        scan_queue[7] = 8'h46;
        scan_queue[8] = 8'h1e;
        scan_queue[9] = 8'h26;
        scan_queue[10] = 8'h25;
        scan_queue[11] = 8'h2e;
        scan_queue[12] = 8'h36;
        scan_count = 13;

        repeat (4) @(posedge clk);
        reset = 1'b0;

        for (cycle = 0; cycle < 200000; cycle = cycle + 1) begin
            @(posedge clk);
            if (scan_idx == scan_count && last_display == 32'hf0923456) begin
                $display("PASS: PS/2 hex FIFO display skipped invalid keys and kept last 8 nibbles: %h", last_display);
                $finish;
            end
        end

        $fatal(1, "FAIL: expected display f0923456, got %h after scan_idx=%0d pc=%h",
               last_display, scan_idx, pc);
    end
endmodule
