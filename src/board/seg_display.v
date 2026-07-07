`timescale 1ns / 1ps

module seg_display(
    input         clk_cpu,
    input         rst,
    input  [31:0] clkdiv,
    input  [2:0]  display_sel,
    input         mem_w,
    input         gpio_display_we,
    input  [31:0] addr_bus,
    input  [31:0] peripheral_in,
    input  [15:0] spio_led,
    input  [31:0] pc,
    input  [31:0] inst,
    input  [9:0]  ram_addr,
    input  [31:0] cpu_data_out,
    input  [31:0] cpu_data_in,
    output reg [15:0] led_o,
    output reg [7:0]  disp_an_o,
    output reg [7:0]  disp_seg_o
);
    localparam DISPLAY_ADDR = 32'he0000000;

    reg  [31:0] display_value;
    reg  [31:0] selected_display_value;
    reg  [3:0]  selected_nibble;
    reg  [7:0]  raw_seg;
    wire        display_we;

    assign display_we = mem_w && (addr_bus == DISPLAY_ADDR);

    always @(posedge clk_cpu or posedge rst) begin
        if (rst)
            display_value <= 32'hffff_ffff;
        else if (display_we || gpio_display_we)
            display_value <= peripheral_in;
    end

    always @(*) begin
        case (display_sel)
            3'b000: led_o = spio_led;
            3'b001: led_o = pc[17:2];
            3'b010: led_o = inst[15:0];
            3'b011: led_o = {13'b0, gpio_display_we, mem_w, display_we};
            3'b100: led_o = {6'b0, ram_addr};
            3'b101: led_o = cpu_data_out[15:0];
            3'b110: led_o = cpu_data_in[15:0];
            default: led_o = addr_bus[15:0];
        endcase
    end

    always @(*) begin
        case (display_sel)
            3'b000: selected_display_value = display_value;
            3'b001: selected_display_value = pc;
            3'b010: selected_display_value = inst;
            3'b011: selected_display_value = display_value;
            3'b100: selected_display_value = {22'b0, ram_addr};
            3'b101: selected_display_value = cpu_data_out;
            3'b110: selected_display_value = cpu_data_in;
            default: selected_display_value = addr_bus;
        endcase
    end

    always @(*) begin
        case (clkdiv[14:13])
            2'd0: raw_seg = display_value[7:0];
            2'd1: raw_seg = display_value[15:8];
            2'd2: raw_seg = display_value[23:16];
            default: raw_seg = display_value[31:24];
        endcase
    end

    always @(*) begin
        case (clkdiv[15:13])
            3'd0: begin disp_an_o = 8'b1111_1110; selected_nibble = selected_display_value[3:0]; end
            3'd1: begin disp_an_o = 8'b1111_1101; selected_nibble = selected_display_value[7:4]; end
            3'd2: begin disp_an_o = 8'b1111_1011; selected_nibble = selected_display_value[11:8]; end
            3'd3: begin disp_an_o = 8'b1111_0111; selected_nibble = selected_display_value[15:12]; end
            3'd4: begin disp_an_o = 8'b1110_1111; selected_nibble = selected_display_value[19:16]; end
            3'd5: begin disp_an_o = 8'b1101_1111; selected_nibble = selected_display_value[23:20]; end
            3'd6: begin disp_an_o = 8'b1011_1111; selected_nibble = selected_display_value[27:24]; end
            default: begin disp_an_o = 8'b0111_1111; selected_nibble = selected_display_value[31:28]; end
        endcase

        disp_seg_o = (display_sel == 3'b000) ? raw_seg : hex_to_seg(selected_nibble);
    end

    function [7:0] hex_to_seg;
        input [3:0] hex;
        begin
            case (hex)
                4'h0: hex_to_seg = 8'b1100_0000;
                4'h1: hex_to_seg = 8'b1111_1001;
                4'h2: hex_to_seg = 8'b1010_0100;
                4'h3: hex_to_seg = 8'b1011_0000;
                4'h4: hex_to_seg = 8'b1001_1001;
                4'h5: hex_to_seg = 8'b1001_0010;
                4'h6: hex_to_seg = 8'b1000_0010;
                4'h7: hex_to_seg = 8'b1111_1000;
                4'h8: hex_to_seg = 8'b1000_0000;
                4'h9: hex_to_seg = 8'b1001_0000;
                4'ha: hex_to_seg = 8'b1000_1000;
                4'hb: hex_to_seg = 8'b1000_0011;
                4'hc: hex_to_seg = 8'b1100_0110;
                4'hd: hex_to_seg = 8'b1010_0001;
                4'he: hex_to_seg = 8'b1000_0110;
                default: hex_to_seg = 8'b1000_1110;
            endcase
        end
    endfunction

endmodule
