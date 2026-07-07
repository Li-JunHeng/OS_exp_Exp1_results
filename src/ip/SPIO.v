`timescale 1ns / 1ps

module SPIO(
    input         clk,
    input         rst,
    input         EN,
    input  [31:0] P_Data,
    output [1:0]  counter_set,
    output [15:0] LED_out,
    output [15:0] led,
    output [13:0] GPIOf0
);
    reg [15:0] led_reg;

    always @(posedge clk or posedge rst) begin
        if (rst)
            led_reg <= 16'b0;
        else if (EN)
            led_reg <= P_Data[15:0];
    end

    assign counter_set = P_Data[1:0];
    assign LED_out = led_reg;
    assign led = led_reg;
    assign GPIOf0 = led_reg[13:0];
endmodule
