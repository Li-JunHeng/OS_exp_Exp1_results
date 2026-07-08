`timescale 1ns / 1ps

module tb_vga_timing;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg mem_w = 1'b0;
    reg mem_r = 1'b0;
    reg [31:0] addr = 32'b0;
    reg [31:0] wdata = 32'b0;

    wire [31:0] rdata;
    wire vblank_irq;
    wire hsync;
    wire vsync;
    wire [3:0] red;
    wire [3:0] green;
    wire [3:0] blue;

    integer cycle;
    reg saw_vblank;

    vga_tile_sprite_display U_VGA(
        .clk(clk),
        .rst(rst),
        .mem_w(mem_w),
        .mem_r(mem_r),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .vblank_irq(vblank_irq),
        .vga_hsync(hsync),
        .vga_vsync(vsync),
        .vga_red(red),
        .vga_green(green),
        .vga_blue(blue)
    );

    always #5 clk = ~clk;

    task write_mmio;
        input [31:0] a;
        input [31:0] d;
        begin
            @(negedge clk);
            addr = a;
            wdata = d;
            mem_w = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mem_w = 1'b0;
        end
    endtask

    initial begin
        repeat (8) @(posedge clk);
        rst = 1'b0;

        saw_vblank = 1'b0;
        for (cycle = 0; cycle < 800 * 525 * 4 + 100; cycle = cycle + 1) begin
            @(posedge clk);
            if (U_VGA.h_count >= 10'd656 && U_VGA.h_count < 10'd752 && hsync != 1'b0) begin
                $fatal(1, "hsync was not low in sync interval");
            end
            if (U_VGA.v_count >= 10'd490 && U_VGA.v_count < 10'd492 && vsync != 1'b0) begin
                $fatal(1, "vsync was not low in sync interval");
            end
            if (vblank_irq) begin
                saw_vblank = 1'b1;
            end
        end

        if (!saw_vblank) begin
            $fatal(1, "VBlank IRQ was not raised");
        end

        write_mmio(32'hc0000004, 32'h00000001);
        repeat (4) @(posedge clk);
        if (vblank_irq) begin
            $fatal(1, "VBlank IRQ did not clear through VGA_STATUS");
        end

        $display("PASS: VGA timing and VBlank status worked");
        $finish;
    end
endmodule
