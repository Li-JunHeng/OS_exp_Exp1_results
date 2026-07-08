`timescale 1ns / 1ps

module vga_hex_display(
    input         clk,
    input         rst,
    input  [31:0] value,
    output        vga_hsync,
    output        vga_vsync,
    output [11:0] vga_rgb
);
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    reg pix_clk;
    reg [9:0] h_count;
    reg [9:0] v_count;

    wire visible = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    wire [9:0] glyph_x = h_count - 10'd96;
    wire [9:0] glyph_y = v_count - 10'd192;
    wire in_text = visible && h_count >= 10'd96 && h_count < 10'd544 &&
                   v_count >= 10'd192 && v_count < 10'd256;
    wire [2:0] digit_index = glyph_x[8:6];
    wire [2:0] col = glyph_x[5:3];
    wire [2:0] row = glyph_y[5:3];
    reg [3:0] digit;
    reg [6:0] seg;
    reg pixel_on;

    assign vga_hsync = ~((h_count >= H_VISIBLE + H_FRONT) &&
                         (h_count < H_VISIBLE + H_FRONT + H_SYNC));
    assign vga_vsync = ~((v_count >= V_VISIBLE + V_FRONT) &&
                         (v_count < V_VISIBLE + V_FRONT + V_SYNC));
    assign vga_rgb = (visible && pixel_on) ? 12'h0f0 :
                     visible ? 12'h002 : 12'h000;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pix_clk <= 1'b0;
        end else begin
            pix_clk <= ~pix_clk;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h_count <= 10'b0;
            v_count <= 10'b0;
        end else if (pix_clk) begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'b0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'b0;
                else
                    v_count <= v_count + 1'b1;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    always @(*) begin
        case (digit_index)
            3'd0: digit = value[31:28];
            3'd1: digit = value[27:24];
            3'd2: digit = value[23:20];
            3'd3: digit = value[19:16];
            3'd4: digit = value[15:12];
            3'd5: digit = value[11:8];
            3'd6: digit = value[7:4];
            default: digit = value[3:0];
        endcase

        case (digit)
            4'h0: seg = 7'b1111110;
            4'h1: seg = 7'b0110000;
            4'h2: seg = 7'b1101101;
            4'h3: seg = 7'b1111001;
            4'h4: seg = 7'b0110011;
            4'h5: seg = 7'b1011011;
            4'h6: seg = 7'b1011111;
            4'h7: seg = 7'b1110000;
            4'h8: seg = 7'b1111111;
            4'h9: seg = 7'b1111011;
            4'ha: seg = 7'b1110111;
            4'hb: seg = 7'b0011111;
            4'hc: seg = 7'b1001110;
            4'hd: seg = 7'b0111101;
            4'he: seg = 7'b1001111;
            default: seg = 7'b1000111;
        endcase

        pixel_on = 1'b0;
        if (in_text) begin
            if (seg[6] && row == 3'd0 && col >= 3'd1 && col <= 3'd6)
                pixel_on = 1'b1;
            if (seg[5] && col == 3'd6 && row >= 3'd1 && row <= 3'd3)
                pixel_on = 1'b1;
            if (seg[4] && col == 3'd6 && row >= 3'd4 && row <= 3'd6)
                pixel_on = 1'b1;
            if (seg[3] && row == 3'd6 && col >= 3'd1 && col <= 3'd6)
                pixel_on = 1'b1;
            if (seg[2] && col == 3'd0 && row >= 3'd4 && row <= 3'd6)
                pixel_on = 1'b1;
            if (seg[1] && col == 3'd0 && row >= 3'd1 && row <= 3'd3)
                pixel_on = 1'b1;
            if (seg[0] && row == 3'd3 && col >= 3'd1 && col <= 3'd6)
                pixel_on = 1'b1;
        end
    end
endmodule
