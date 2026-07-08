`timescale 1ns / 1ps

module tb_vga_mmio;
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

    task read_expect;
        input [31:0] a;
        input [31:0] d;
        begin
            @(negedge clk);
            addr = a;
            mem_r = 1'b1;
            @(posedge clk);
            #1;
            if (rdata !== d) begin
                $fatal(1, "read mismatch at %h expected %h got %h", a, d, rdata);
            end
            @(negedge clk);
            mem_r = 1'b0;
        end
    endtask

    initial begin
        repeat (8) @(posedge clk);
        rst = 1'b0;

        write_mmio(32'hc0000000, 32'h00000001);
        write_mmio(32'hc0000100, 32'h00000004);
        write_mmio(32'hc0001000, 32'h00000000);
        write_mmio(32'hc0001004, 32'h00000000);
        write_mmio(32'hc0001008, 32'h00000008);
        write_mmio(32'hc000100c, 32'h00000001);
        write_mmio(32'hc000203c, 32'h00000f0f);

        read_expect(32'hc0000000, 32'h00000001);
        read_expect(32'hc0000100, 32'h00000004);
        read_expect(32'hc0001008, 32'h00000008);
        read_expect(32'hc000203c, 32'h00000f0f);

        repeat (16) @(posedge clk);
        if ({red, green, blue} == 12'h000) begin
            $fatal(1, "VGA pixel output stayed black after sprite/palette writes");
        end

        $display("PASS: VGA MMIO updated tilemap, sprite table, palette, and pixels");
        $finish;
    end
endmodule
