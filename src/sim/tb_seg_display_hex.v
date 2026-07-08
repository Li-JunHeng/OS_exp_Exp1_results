`timescale 1ns / 1ps

module tb_seg_display_hex;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [31:0] clkdiv = 32'b0;
    reg [2:0] display_sel = 3'b000;
    reg mem_w = 1'b0;
    reg gpio_display_we = 1'b0;
    reg [31:0] addr_bus = 32'he0000000;
    reg [31:0] peripheral_in = 32'hf0923456;

    wire [31:0] display_value;
    wire [15:0] led_o;
    wire [7:0] disp_an_o;
    wire [7:0] disp_seg_o;

    seg_display U_SEG_DISPLAY(
        .clk_cpu(clk),
        .rst(rst),
        .clkdiv(clkdiv),
        .display_sel(display_sel),
        .mem_w(mem_w),
        .gpio_display_we(gpio_display_we),
        .addr_bus(addr_bus),
        .peripheral_in(peripheral_in),
        .spio_led(16'b0),
        .pc(32'b0),
        .inst(32'b0),
        .ram_addr(10'b0),
        .cpu_data_out(32'b0),
        .cpu_data_in(32'b0),
        .display_value_o(display_value),
        .led_o(led_o),
        .disp_an_o(disp_an_o),
        .disp_seg_o(disp_seg_o)
    );

    always #5 clk = ~clk;

    task expect_digit;
        input [2:0] idx;
        input [7:0] expected_seg;
        begin
            clkdiv = {16'b0, idx, 13'b0};
            #1;
            if (disp_seg_o !== expected_seg) begin
                $fatal(1, "digit %0d segment mismatch: expected=%b actual=%b",
                       idx, expected_seg, disp_seg_o);
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        mem_w = 1'b1;
        @(posedge clk);
        mem_w = 1'b0;
        #1;

        if (display_value !== 32'hf0923456) begin
            $fatal(1, "display_value mismatch: %h", display_value);
        end

        display_sel = 3'b000;
        expect_digit(3'd0, 8'b1000_0010); // 6
        expect_digit(3'd1, 8'b1001_0010); // 5
        expect_digit(3'd2, 8'b1001_1001); // 4
        expect_digit(3'd3, 8'b1011_0000); // 3
        expect_digit(3'd4, 8'b1010_0100); // 2
        expect_digit(3'd5, 8'b1001_0000); // 9
        expect_digit(3'd6, 8'b1100_0000); // 0
        expect_digit(3'd7, 8'b1000_1110); // F

        display_sel = 3'b111;
        expect_digit(3'd0, 8'b1100_0000); // default mode decodes addr_bus[3:0] as hex 0

        $display("PASS: display output decodes eight independent hex nibbles, not 4x2 raw bytes");
        $finish;
    end
endmodule
