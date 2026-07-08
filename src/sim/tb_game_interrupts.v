`timescale 1ns / 1ps

module tb_game_interrupts;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg ps2_clk = 1'b1;
    reg ps2_data = 1'b1;
    reg ps2_rd_en = 1'b0;
    reg ps2_clear_errors = 1'b0;
    reg vga_mem_w = 1'b0;
    reg [31:0] vga_addr = 32'b0;
    reg [31:0] vga_wdata = 32'b0;

    wire [7:0] ps2_rx_data;
    wire [7:0] ps2_latest_data;
    wire ps2_data_valid;
    wire ps2_irq;
    wire [3:0] ps2_data_count;
    wire ps2_fifo_full;
    wire ps2_overflow;
    wire ps2_frame_error;
    wire ps2_parity_error;
    wire [31:0] vga_rdata;
    wire vblank_irq;
    wire hsync;
    wire vsync;
    wire [3:0] red;
    wire [3:0] green;
    wire [3:0] blue;

    integer cycle;
    reg saw_vblank;

    ps2_keyboard U_PS2(
        .wr_clk(clk),
        .rd_clk(clk),
        .rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .rd_en(ps2_rd_en),
        .clear_errors(ps2_clear_errors),
        .data(ps2_rx_data),
        .latest_data(ps2_latest_data),
        .data_valid(ps2_data_valid),
        .irq(ps2_irq),
        .data_count(ps2_data_count),
        .fifo_full(ps2_fifo_full),
        .overflow(ps2_overflow),
        .frame_error(ps2_frame_error),
        .parity_error(ps2_parity_error)
    );

    vga_tile_sprite_display U_VGA(
        .clk(clk),
        .rst(rst),
        .mem_w(vga_mem_w),
        .mem_r(1'b0),
        .addr(vga_addr),
        .wdata(vga_wdata),
        .rdata(vga_rdata),
        .vblank_irq(vblank_irq),
        .vga_hsync(hsync),
        .vga_vsync(vsync),
        .vga_red(red),
        .vga_green(green),
        .vga_blue(blue)
    );

    always #5 clk = ~clk;

    task ps2_bit;
        input bit_value;
        begin
            ps2_data = bit_value;
            repeat (20) @(posedge clk);
            ps2_clk = 1'b0;
            repeat (20) @(posedge clk);
            ps2_clk = 1'b1;
            repeat (20) @(posedge clk);
        end
    endtask

    task ps2_byte;
        input [7:0] code;
        integer i;
        reg parity_bit;
        begin
            parity_bit = ~(^code);
            ps2_bit(1'b0);
            for (i = 0; i < 8; i = i + 1) begin
                ps2_bit(code[i]);
            end
            ps2_bit(parity_bit);
            ps2_bit(1'b1);
            ps2_data = 1'b1;
            repeat (50) @(posedge clk);
        end
    endtask

    task clear_vblank;
        begin
            @(negedge clk);
            vga_addr = 32'hc0000004;
            vga_wdata = 32'h00000001;
            vga_mem_w = 1'b1;
            @(posedge clk);
            @(negedge clk);
            vga_mem_w = 1'b0;
        end
    endtask

    initial begin
        repeat (8) @(posedge clk);
        rst = 1'b0;

        ps2_byte(8'h1d);
        repeat (20) @(posedge clk);
        if (!ps2_irq || !ps2_data_valid || ps2_rx_data != 8'h1d) begin
            $fatal(1, "PS/2 keyboard IRQ source did not expose W make code");
        end
        ps2_rd_en = 1'b1;
        @(posedge clk);
        ps2_rd_en = 1'b0;

        saw_vblank = 1'b0;
        for (cycle = 0; cycle < 800 * 525 * 4 + 100; cycle = cycle + 1) begin
            @(posedge clk);
            if (vblank_irq) begin
                saw_vblank = 1'b1;
            end
        end

        if (!saw_vblank || !vblank_irq) begin
            $fatal(1, "VGA VBlank IRQ source did not assert");
        end
        clear_vblank();
        repeat (4) @(posedge clk);
        if (vblank_irq) begin
            $fatal(1, "VGA VBlank IRQ source did not clear");
        end

        $display("PASS: game IRQ sources for PS/2 keyboard and VBlank worked");
        $finish;
    end
endmodule
