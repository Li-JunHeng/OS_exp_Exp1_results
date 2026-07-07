`timescale 1ns / 1ps

module clk_div(
    input             clk,
    input             rst,
    input             SW2,
    output reg [31:0] clkdiv,
    output reg        Clk_CPU
);
    localparam [31:0] FAST_HALF_PERIOD = 32'd24;         // SW2=0: demo, 2,000,000 instructions per second
    localparam [31:0] SLOW_HALF_PERIOD = 32'd49_999_999; // SW2=1: debug, 1.00 s per instruction

    reg [31:0] cpu_cnt;
    reg        sw2_d;

    wire [31:0] cpu_half_period = SW2 ? SLOW_HALF_PERIOD : FAST_HALF_PERIOD;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clkdiv <= 32'b0;
            cpu_cnt <= 32'b0;
            Clk_CPU <= 1'b0;
            sw2_d <= 1'b0;
        end else begin
            clkdiv <= clkdiv + 1'b1;
            sw2_d <= SW2;

            if (sw2_d != SW2) begin
                cpu_cnt <= 32'b0;
                Clk_CPU <= 1'b0;
            end else if (cpu_cnt == cpu_half_period) begin
                cpu_cnt <= 32'b0;
                Clk_CPU <= ~Clk_CPU;
            end else begin
                cpu_cnt <= cpu_cnt + 1'b1;
            end
        end
    end
endmodule
