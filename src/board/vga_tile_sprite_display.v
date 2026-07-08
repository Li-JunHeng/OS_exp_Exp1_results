`timescale 1ns / 1ps

module vga_tile_sprite_display(
    input         clk,
    input         rst,
    input         mem_w,
    input         mem_r,
    input  [31:0] addr,
    input  [31:0] wdata,
    output reg [31:0] rdata,
    output        vblank_irq,
    output        vga_hsync,
    output        vga_vsync,
    output [3:0]  vga_red,
    output [3:0]  vga_green,
    output [3:0]  vga_blue
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

    localparam TILE_COUNT   = 336;
    localparam SPRITE_WORDS = 128;
    localparam PALETTE_SIZE = 16;

    reg [1:0] pix_div;
    wire pix_tick = (pix_div == 2'b00);

    reg [9:0] h_count;
    reg [9:0] v_count;
    reg       graphics_enable;
    reg       vblank_pending;
    reg [3:0] scroll_x;
    reg [3:0] scroll_y;
    reg [31:0] hud0;
    reg [31:0] hud1;

    reg [7:0]  tilemap [0:TILE_COUNT-1];
    reg [31:0] sprite_words [0:SPRITE_WORDS-1];
    reg [11:0] palette [0:PALETTE_SIZE-1];

    wire visible = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    wire [8:0] virtual_x = h_count[9:1];
    wire [7:0] virtual_y = v_count[8:1];
    wire [8:0] scrolled_x = virtual_x + {5'b0, scroll_x};
    wire [7:0] scrolled_y = virtual_y + {4'b0, scroll_y};
    wire [4:0] tile_x = scrolled_x[8:4];
    wire [3:0] tile_y = scrolled_y[7:4];
    wire [3:0] tile_px = scrolled_x[3:0];
    wire [3:0] tile_py = scrolled_y[3:0];
    wire [8:0] tile_index = (tile_y * 9'd21) + tile_x;
    wire [7:0] bg_tile_id = tilemap[tile_index];
    wire [3:0] bg_color = tile_pixel(bg_tile_id, tile_px, tile_py);
    wire [3:0] hud_color = hud_pixel(virtual_x, virtual_y);

    reg [3:0] sprite_color;
    reg [3:0] pixel_color;
    reg [11:0] pixel_rgb;
    reg [7:0] sprite_id;
    reg [8:0] sprite_x;
    reg [8:0] sprite_y;
    reg [8:0] rel_x;
    reg [8:0] rel_y;
    integer i;
    integer init_i;

    wire ctrl_addr = (addr == 32'hc0000000);
    wire status_addr = (addr == 32'hc0000004);
    wire scroll_addr = (addr == 32'hc0000008);
    wire hud0_addr = (addr == 32'hc000000c);
    wire hud1_addr = (addr == 32'hc0000010);
    wire tile_addr = (addr >= 32'hc0000100) && (addr < 32'hc0000100 + (TILE_COUNT * 4));
    wire sprite_addr = (addr >= 32'hc0001000) && (addr < 32'hc0001000 + (SPRITE_WORDS * 4));
    wire palette_addr = (addr >= 32'hc0002000) && (addr < 32'hc0002000 + (PALETTE_SIZE * 4));
    wire [8:0] tile_wr_index = (addr - 32'hc0000100) >> 2;
    wire [6:0] sprite_wr_index = (addr - 32'hc0001000) >> 2;
    wire [3:0] palette_wr_index = (addr - 32'hc0002000) >> 2;

    assign vblank_irq = vblank_pending;
    assign vga_hsync = ~((h_count >= H_VISIBLE + H_FRONT) &&
                         (h_count < H_VISIBLE + H_FRONT + H_SYNC));
    assign vga_vsync = ~((v_count >= V_VISIBLE + V_FRONT) &&
                         (v_count < V_VISIBLE + V_FRONT + V_SYNC));
    assign vga_red   = visible ? pixel_rgb[11:8] : 4'h0;
    assign vga_green = visible ? pixel_rgb[7:4]  : 4'h0;
    assign vga_blue  = visible ? pixel_rgb[3:0]  : 4'h0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pix_div <= 2'b00;
        end else begin
            pix_div <= pix_div + 2'b01;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h_count <= 10'b0;
            v_count <= 10'b0;
            graphics_enable <= 1'b1;
            vblank_pending <= 1'b0;
            scroll_x <= 4'b0;
            scroll_y <= 4'b0;
            hud0 <= 32'b0;
            hud1 <= 32'b0;

            for (init_i = 0; init_i < TILE_COUNT; init_i = init_i + 1) begin
                tilemap[init_i] <= 8'd1;
            end
            for (init_i = 0; init_i < SPRITE_WORDS; init_i = init_i + 1) begin
                sprite_words[init_i] <= 32'b0;
            end

            palette[0] <= 12'h000;
            palette[1] <= 12'h124;
            palette[2] <= 12'h286;
            palette[3] <= 12'h3a5;
            palette[4] <= 12'hd33;
            palette[5] <= 12'hf83;
            palette[6] <= 12'hfc4;
            palette[7] <= 12'hfff;
            palette[8] <= 12'h7cf;
            palette[9] <= 12'h48f;
            palette[10] <= 12'ha5f;
            palette[11] <= 12'hf5a;
            palette[12] <= 12'h964;
            palette[13] <= 12'h777;
            palette[14] <= 12'hbbb;
            palette[15] <= 12'h0f0;
        end else begin
            if (pix_tick) begin
                if (h_count == H_TOTAL - 1) begin
                    h_count <= 10'b0;
                    if (v_count == V_TOTAL - 1) begin
                        v_count <= 10'b0;
                    end else begin
                        v_count <= v_count + 1'b1;
                    end
                end else begin
                    h_count <= h_count + 1'b1;
                end

                if (h_count == 10'b0 && v_count == V_VISIBLE) begin
                    vblank_pending <= 1'b1;
                end
            end

            if (mem_w && ctrl_addr) begin
                graphics_enable <= wdata[0];
            end
            if (mem_w && status_addr && wdata[0]) begin
                vblank_pending <= 1'b0;
            end
            if (mem_w && scroll_addr) begin
                scroll_x <= wdata[3:0];
                scroll_y <= wdata[7:4];
            end
            if (mem_w && hud0_addr) begin
                hud0 <= wdata;
            end
            if (mem_w && hud1_addr) begin
                hud1 <= wdata;
            end
            if (mem_w && tile_addr) begin
                tilemap[tile_wr_index] <= wdata[7:0];
            end
            if (mem_w && sprite_addr) begin
                sprite_words[sprite_wr_index] <= wdata;
            end
            if (mem_w && palette_addr) begin
                palette[palette_wr_index] <= wdata[11:0];
            end
        end
    end

    always @(*) begin
        if (ctrl_addr) begin
            rdata = {31'b0, graphics_enable};
        end else if (status_addr) begin
            rdata = {30'b0, visible, vblank_pending};
        end else if (scroll_addr) begin
            rdata = {24'b0, scroll_y, scroll_x};
        end else if (hud0_addr) begin
            rdata = hud0;
        end else if (hud1_addr) begin
            rdata = hud1;
        end else if (tile_addr) begin
            rdata = {24'b0, tilemap[tile_wr_index]};
        end else if (sprite_addr) begin
            rdata = sprite_words[sprite_wr_index];
        end else if (palette_addr) begin
            rdata = {20'b0, palette[palette_wr_index]};
        end else begin
            rdata = 32'b0;
        end
    end

    always @(*) begin
        sprite_color = 4'b0;
        for (i = 0; i < 32; i = i + 1) begin
            if (sprite_words[(i * 4) + 3][0]) begin
                sprite_x = sprite_words[(i * 4) + 0][8:0];
                sprite_y = sprite_words[(i * 4) + 1][8:0];
                sprite_id = sprite_words[(i * 4) + 2][7:0];
                if ({1'b0, virtual_x} >= sprite_x && {1'b0, virtual_x} < sprite_x + 9'd16 &&
                    {1'b0, virtual_y} >= sprite_y && {1'b0, virtual_y} < sprite_y + 9'd16) begin
                    rel_x = {1'b0, virtual_x} - sprite_x;
                    rel_y = {1'b0, virtual_y} - sprite_y;
                    if (tile_pixel(sprite_id, rel_x[3:0], rel_y[3:0]) != 4'b0) begin
                        sprite_color = tile_pixel(sprite_id, rel_x[3:0], rel_y[3:0]);
                    end
                end
            end
        end

        pixel_color = (sprite_color != 4'b0) ? sprite_color : bg_color;
        if (hud_color != 4'b0) begin
            pixel_color = hud_color;
        end
        pixel_rgb = graphics_enable ? palette[pixel_color] : 12'h000;
    end

    function [4:0] font_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            case ({ch, row})
                {8'h41, 3'd0}: font_row = 5'b01110; {8'h41, 3'd1}: font_row = 5'b10001; {8'h41, 3'd2}: font_row = 5'b10001; {8'h41, 3'd3}: font_row = 5'b11111; {8'h41, 3'd4}: font_row = 5'b10001; {8'h41, 3'd5}: font_row = 5'b10001; {8'h41, 3'd6}: font_row = 5'b10001;
                {8'h42, 3'd0}: font_row = 5'b11110; {8'h42, 3'd1}: font_row = 5'b10001; {8'h42, 3'd2}: font_row = 5'b11110; {8'h42, 3'd3}: font_row = 5'b10001; {8'h42, 3'd4}: font_row = 5'b10001; {8'h42, 3'd5}: font_row = 5'b10001; {8'h42, 3'd6}: font_row = 5'b11110;
                {8'h43, 3'd0}: font_row = 5'b01111; {8'h43, 3'd1}: font_row = 5'b10000; {8'h43, 3'd2}: font_row = 5'b10000; {8'h43, 3'd3}: font_row = 5'b10000; {8'h43, 3'd4}: font_row = 5'b10000; {8'h43, 3'd5}: font_row = 5'b10000; {8'h43, 3'd6}: font_row = 5'b01111;
                {8'h44, 3'd0}: font_row = 5'b11110; {8'h44, 3'd1}: font_row = 5'b10001; {8'h44, 3'd2}: font_row = 5'b10001; {8'h44, 3'd3}: font_row = 5'b10001; {8'h44, 3'd4}: font_row = 5'b10001; {8'h44, 3'd5}: font_row = 5'b10001; {8'h44, 3'd6}: font_row = 5'b11110;
                {8'h45, 3'd0}: font_row = 5'b11111; {8'h45, 3'd1}: font_row = 5'b10000; {8'h45, 3'd2}: font_row = 5'b11110; {8'h45, 3'd3}: font_row = 5'b10000; {8'h45, 3'd4}: font_row = 5'b10000; {8'h45, 3'd5}: font_row = 5'b10000; {8'h45, 3'd6}: font_row = 5'b11111;
                {8'h46, 3'd0}: font_row = 5'b11111; {8'h46, 3'd1}: font_row = 5'b10000; {8'h46, 3'd2}: font_row = 5'b11110; {8'h46, 3'd3}: font_row = 5'b10000; {8'h46, 3'd4}: font_row = 5'b10000; {8'h46, 3'd5}: font_row = 5'b10000; {8'h46, 3'd6}: font_row = 5'b10000;
                {8'h47, 3'd0}: font_row = 5'b01111; {8'h47, 3'd1}: font_row = 5'b10000; {8'h47, 3'd2}: font_row = 5'b10000; {8'h47, 3'd3}: font_row = 5'b10011; {8'h47, 3'd4}: font_row = 5'b10001; {8'h47, 3'd5}: font_row = 5'b10001; {8'h47, 3'd6}: font_row = 5'b01111;
                {8'h48, 3'd0}: font_row = 5'b10001; {8'h48, 3'd1}: font_row = 5'b10001; {8'h48, 3'd2}: font_row = 5'b11111; {8'h48, 3'd3}: font_row = 5'b10001; {8'h48, 3'd4}: font_row = 5'b10001; {8'h48, 3'd5}: font_row = 5'b10001; {8'h48, 3'd6}: font_row = 5'b10001;
                {8'h49, 3'd0}: font_row = 5'b11111; {8'h49, 3'd1}: font_row = 5'b00100; {8'h49, 3'd2}: font_row = 5'b00100; {8'h49, 3'd3}: font_row = 5'b00100; {8'h49, 3'd4}: font_row = 5'b00100; {8'h49, 3'd5}: font_row = 5'b00100; {8'h49, 3'd6}: font_row = 5'b11111;
                {8'h4a, 3'd0}: font_row = 5'b00111; {8'h4a, 3'd1}: font_row = 5'b00010; {8'h4a, 3'd2}: font_row = 5'b00010; {8'h4a, 3'd3}: font_row = 5'b00010; {8'h4a, 3'd4}: font_row = 5'b10010; {8'h4a, 3'd5}: font_row = 5'b10010; {8'h4a, 3'd6}: font_row = 5'b01100;
                {8'h4b, 3'd0}: font_row = 5'b10001; {8'h4b, 3'd1}: font_row = 5'b10010; {8'h4b, 3'd2}: font_row = 5'b10100; {8'h4b, 3'd3}: font_row = 5'b11000; {8'h4b, 3'd4}: font_row = 5'b10100; {8'h4b, 3'd5}: font_row = 5'b10010; {8'h4b, 3'd6}: font_row = 5'b10001;
                {8'h4c, 3'd0}: font_row = 5'b10000; {8'h4c, 3'd1}: font_row = 5'b10000; {8'h4c, 3'd2}: font_row = 5'b10000; {8'h4c, 3'd3}: font_row = 5'b10000; {8'h4c, 3'd4}: font_row = 5'b10000; {8'h4c, 3'd5}: font_row = 5'b10000; {8'h4c, 3'd6}: font_row = 5'b11111;
                {8'h4d, 3'd0}: font_row = 5'b10001; {8'h4d, 3'd1}: font_row = 5'b11011; {8'h4d, 3'd2}: font_row = 5'b10101; {8'h4d, 3'd3}: font_row = 5'b10101; {8'h4d, 3'd4}: font_row = 5'b10001; {8'h4d, 3'd5}: font_row = 5'b10001; {8'h4d, 3'd6}: font_row = 5'b10001;
                {8'h4e, 3'd0}: font_row = 5'b10001; {8'h4e, 3'd1}: font_row = 5'b11001; {8'h4e, 3'd2}: font_row = 5'b10101; {8'h4e, 3'd3}: font_row = 5'b10011; {8'h4e, 3'd4}: font_row = 5'b10001; {8'h4e, 3'd5}: font_row = 5'b10001; {8'h4e, 3'd6}: font_row = 5'b10001;
                {8'h4f, 3'd0}: font_row = 5'b01110; {8'h4f, 3'd1}: font_row = 5'b10001; {8'h4f, 3'd2}: font_row = 5'b10001; {8'h4f, 3'd3}: font_row = 5'b10001; {8'h4f, 3'd4}: font_row = 5'b10001; {8'h4f, 3'd5}: font_row = 5'b10001; {8'h4f, 3'd6}: font_row = 5'b01110;
                {8'h50, 3'd0}: font_row = 5'b11110; {8'h50, 3'd1}: font_row = 5'b10001; {8'h50, 3'd2}: font_row = 5'b10001; {8'h50, 3'd3}: font_row = 5'b11110; {8'h50, 3'd4}: font_row = 5'b10000; {8'h50, 3'd5}: font_row = 5'b10000; {8'h50, 3'd6}: font_row = 5'b10000;
                {8'h51, 3'd0}: font_row = 5'b01110; {8'h51, 3'd1}: font_row = 5'b10001; {8'h51, 3'd2}: font_row = 5'b10001; {8'h51, 3'd3}: font_row = 5'b10001; {8'h51, 3'd4}: font_row = 5'b10101; {8'h51, 3'd5}: font_row = 5'b10010; {8'h51, 3'd6}: font_row = 5'b01101;
                {8'h52, 3'd0}: font_row = 5'b11110; {8'h52, 3'd1}: font_row = 5'b10001; {8'h52, 3'd2}: font_row = 5'b10001; {8'h52, 3'd3}: font_row = 5'b11110; {8'h52, 3'd4}: font_row = 5'b10100; {8'h52, 3'd5}: font_row = 5'b10010; {8'h52, 3'd6}: font_row = 5'b10001;
                {8'h53, 3'd0}: font_row = 5'b01111; {8'h53, 3'd1}: font_row = 5'b10000; {8'h53, 3'd2}: font_row = 5'b10000; {8'h53, 3'd3}: font_row = 5'b01110; {8'h53, 3'd4}: font_row = 5'b00001; {8'h53, 3'd5}: font_row = 5'b00001; {8'h53, 3'd6}: font_row = 5'b11110;
                {8'h54, 3'd0}: font_row = 5'b11111; {8'h54, 3'd1}: font_row = 5'b00100; {8'h54, 3'd2}: font_row = 5'b00100; {8'h54, 3'd3}: font_row = 5'b00100; {8'h54, 3'd4}: font_row = 5'b00100; {8'h54, 3'd5}: font_row = 5'b00100; {8'h54, 3'd6}: font_row = 5'b00100;
                {8'h55, 3'd0}: font_row = 5'b10001; {8'h55, 3'd1}: font_row = 5'b10001; {8'h55, 3'd2}: font_row = 5'b10001; {8'h55, 3'd3}: font_row = 5'b10001; {8'h55, 3'd4}: font_row = 5'b10001; {8'h55, 3'd5}: font_row = 5'b10001; {8'h55, 3'd6}: font_row = 5'b01110;
                {8'h56, 3'd0}: font_row = 5'b10001; {8'h56, 3'd1}: font_row = 5'b10001; {8'h56, 3'd2}: font_row = 5'b10001; {8'h56, 3'd3}: font_row = 5'b10001; {8'h56, 3'd4}: font_row = 5'b01010; {8'h56, 3'd5}: font_row = 5'b01010; {8'h56, 3'd6}: font_row = 5'b00100;
                {8'h57, 3'd0}: font_row = 5'b10001; {8'h57, 3'd1}: font_row = 5'b10001; {8'h57, 3'd2}: font_row = 5'b10001; {8'h57, 3'd3}: font_row = 5'b10101; {8'h57, 3'd4}: font_row = 5'b10101; {8'h57, 3'd5}: font_row = 5'b11011; {8'h57, 3'd6}: font_row = 5'b10001;
                {8'h58, 3'd0}: font_row = 5'b10001; {8'h58, 3'd1}: font_row = 5'b01010; {8'h58, 3'd2}: font_row = 5'b00100; {8'h58, 3'd3}: font_row = 5'b00100; {8'h58, 3'd4}: font_row = 5'b00100; {8'h58, 3'd5}: font_row = 5'b01010; {8'h58, 3'd6}: font_row = 5'b10001;
                {8'h59, 3'd0}: font_row = 5'b10001; {8'h59, 3'd1}: font_row = 5'b01010; {8'h59, 3'd2}: font_row = 5'b00100; {8'h59, 3'd3}: font_row = 5'b00100; {8'h59, 3'd4}: font_row = 5'b00100; {8'h59, 3'd5}: font_row = 5'b00100; {8'h59, 3'd6}: font_row = 5'b00100;
                {8'h5a, 3'd0}: font_row = 5'b11111; {8'h5a, 3'd1}: font_row = 5'b00001; {8'h5a, 3'd2}: font_row = 5'b00010; {8'h5a, 3'd3}: font_row = 5'b00100; {8'h5a, 3'd4}: font_row = 5'b01000; {8'h5a, 3'd5}: font_row = 5'b10000; {8'h5a, 3'd6}: font_row = 5'b11111;
                {8'h30, 3'd0}: font_row = 5'b01110; {8'h30, 3'd1}: font_row = 5'b10001; {8'h30, 3'd2}: font_row = 5'b10011; {8'h30, 3'd3}: font_row = 5'b10101; {8'h30, 3'd4}: font_row = 5'b11001; {8'h30, 3'd5}: font_row = 5'b10001; {8'h30, 3'd6}: font_row = 5'b01110;
                {8'h31, 3'd0}: font_row = 5'b00100; {8'h31, 3'd1}: font_row = 5'b01100; {8'h31, 3'd2}: font_row = 5'b00100; {8'h31, 3'd3}: font_row = 5'b00100; {8'h31, 3'd4}: font_row = 5'b00100; {8'h31, 3'd5}: font_row = 5'b00100; {8'h31, 3'd6}: font_row = 5'b01110;
                {8'h32, 3'd0}: font_row = 5'b01110; {8'h32, 3'd1}: font_row = 5'b10001; {8'h32, 3'd2}: font_row = 5'b00001; {8'h32, 3'd3}: font_row = 5'b00010; {8'h32, 3'd4}: font_row = 5'b00100; {8'h32, 3'd5}: font_row = 5'b01000; {8'h32, 3'd6}: font_row = 5'b11111;
                {8'h33, 3'd0}: font_row = 5'b11110; {8'h33, 3'd1}: font_row = 5'b00001; {8'h33, 3'd2}: font_row = 5'b00001; {8'h33, 3'd3}: font_row = 5'b01110; {8'h33, 3'd4}: font_row = 5'b00001; {8'h33, 3'd5}: font_row = 5'b00001; {8'h33, 3'd6}: font_row = 5'b11110;
                {8'h34, 3'd0}: font_row = 5'b00010; {8'h34, 3'd1}: font_row = 5'b00110; {8'h34, 3'd2}: font_row = 5'b01010; {8'h34, 3'd3}: font_row = 5'b10010; {8'h34, 3'd4}: font_row = 5'b11111; {8'h34, 3'd5}: font_row = 5'b00010; {8'h34, 3'd6}: font_row = 5'b00010;
                {8'h35, 3'd0}: font_row = 5'b11111; {8'h35, 3'd1}: font_row = 5'b10000; {8'h35, 3'd2}: font_row = 5'b10000; {8'h35, 3'd3}: font_row = 5'b11110; {8'h35, 3'd4}: font_row = 5'b00001; {8'h35, 3'd5}: font_row = 5'b00001; {8'h35, 3'd6}: font_row = 5'b11110;
                {8'h36, 3'd0}: font_row = 5'b01110; {8'h36, 3'd1}: font_row = 5'b10000; {8'h36, 3'd2}: font_row = 5'b10000; {8'h36, 3'd3}: font_row = 5'b11110; {8'h36, 3'd4}: font_row = 5'b10001; {8'h36, 3'd5}: font_row = 5'b10001; {8'h36, 3'd6}: font_row = 5'b01110;
                {8'h37, 3'd0}: font_row = 5'b11111; {8'h37, 3'd1}: font_row = 5'b00001; {8'h37, 3'd2}: font_row = 5'b00010; {8'h37, 3'd3}: font_row = 5'b00100; {8'h37, 3'd4}: font_row = 5'b01000; {8'h37, 3'd5}: font_row = 5'b01000; {8'h37, 3'd6}: font_row = 5'b01000;
                {8'h38, 3'd0}: font_row = 5'b01110; {8'h38, 3'd1}: font_row = 5'b10001; {8'h38, 3'd2}: font_row = 5'b10001; {8'h38, 3'd3}: font_row = 5'b01110; {8'h38, 3'd4}: font_row = 5'b10001; {8'h38, 3'd5}: font_row = 5'b10001; {8'h38, 3'd6}: font_row = 5'b01110;
                {8'h39, 3'd0}: font_row = 5'b01110; {8'h39, 3'd1}: font_row = 5'b10001; {8'h39, 3'd2}: font_row = 5'b10001; {8'h39, 3'd3}: font_row = 5'b01111; {8'h39, 3'd4}: font_row = 5'b00001; {8'h39, 3'd5}: font_row = 5'b00001; {8'h39, 3'd6}: font_row = 5'b01110;
                {8'h2f, 3'd0}: font_row = 5'b00001; {8'h2f, 3'd1}: font_row = 5'b00010; {8'h2f, 3'd2}: font_row = 5'b00010; {8'h2f, 3'd3}: font_row = 5'b00100; {8'h2f, 3'd4}: font_row = 5'b01000; {8'h2f, 3'd5}: font_row = 5'b01000; {8'h2f, 3'd6}: font_row = 5'b10000;
                {8'h3e, 3'd0}: font_row = 5'b10000; {8'h3e, 3'd1}: font_row = 5'b01000; {8'h3e, 3'd2}: font_row = 5'b00100; {8'h3e, 3'd3}: font_row = 5'b00010; {8'h3e, 3'd4}: font_row = 5'b00100; {8'h3e, 3'd5}: font_row = 5'b01000; {8'h3e, 3'd6}: font_row = 5'b10000;
                default: font_row = 5'b00000;
            endcase
        end
    endfunction

    function [7:0] dec_tens;
        input [3:0] value;
        begin
            dec_tens = (value >= 4'd10) ? 8'h31 : 8'h30;
        end
    endfunction

    function [7:0] dec_ones;
        input [3:0] value;
        begin
            dec_ones = 8'h30 + ((value >= 4'd10) ? (value - 4'd10) : value);
        end
    endfunction

    function [7:0] hud_char;
        input [5:0] index;
        begin
            case (index)
                6'd0: hud_char = 8'h48; 6'd1: hud_char = 8'h50; 6'd2: hud_char = dec_tens(hud0[3:0]); 6'd3: hud_char = dec_ones(hud0[3:0]); 6'd4: hud_char = 8'h2f; 6'd5: hud_char = dec_tens(hud0[7:4]); 6'd6: hud_char = dec_ones(hud0[7:4]);
                6'd8: hud_char = 8'h41; 6'd9: hud_char = 8'h52; 6'd10: hud_char = dec_tens(hud0[11:8]); 6'd11: hud_char = dec_ones(hud0[11:8]); 6'd12: hud_char = 8'h2f; 6'd13: hud_char = dec_tens(hud0[15:12]); 6'd14: hud_char = dec_ones(hud0[15:12]);
                6'd16: hud_char = 8'h4c; 6'd17: hud_char = 8'h56; 6'd18: hud_char = dec_tens(hud0[19:16]); 6'd19: hud_char = dec_ones(hud0[19:16]);
                6'd21: hud_char = 8'h41; 6'd22: hud_char = 8'h54; 6'd23: hud_char = 8'h4b; 6'd24: hud_char = dec_tens(hud0[23:20]); 6'd25: hud_char = dec_ones(hud0[23:20]);
                6'd27: hud_char = 8'h57; 6'd28: hud_char = dec_tens(hud0[27:24]); 6'd29: hud_char = dec_ones(hud0[27:24]);
                6'd31: hud_char = 8'h58; 6'd32: hud_char = 8'h50; 6'd33: hud_char = dec_tens(hud1[7:4]); 6'd34: hud_char = dec_ones(hud1[7:4]); 6'd35: hud_char = 8'h2f; 6'd36: hud_char = dec_tens(hud1[11:8]); 6'd37: hud_char = dec_ones(hud1[11:8]);
                6'd39: hud_char = 8'h46; 6'd40: hud_char = dec_tens(hud0[31:28]); 6'd41: hud_char = dec_ones(hud0[31:28]);
                6'd43: hud_char = 8'h52; 6'd44: hud_char = dec_tens(hud1[3:0]); 6'd45: hud_char = dec_ones(hud1[3:0]);
                default: hud_char = 8'h20;
            endcase
        end
    endfunction

    function [3:0] hud_pixel;
        input [8:0] x;
        input [7:0] y;
        reg [5:0] ch_index;
        reg [8:0] ch_start;
        reg [2:0] ch_x;
        reg [2:0] ch_y;
        reg [7:0] ch;
        reg [4:0] row_bits;
        begin
            hud_pixel = 4'h0;
            if (hud1[31] && y < 8'd9) begin
                hud_pixel = 4'hd;
                ch_index = x / 9'd6;
                ch_start = ch_index * 9'd6;
                ch_x = x - ch_start;
                ch_y = y[2:0] - 3'd1;
                ch = hud_char(ch_index);
                if (y >= 8'd1 && y <= 8'd7 && ch_x < 3'd5 && ch != 8'h20) begin
                    row_bits = font_row(ch, ch_y);
                    if (row_bits[4 - ch_x]) begin
                        hud_pixel = 4'hf;
                    end
                end
            end
        end
    endfunction

    function [3:0] tile_pixel;
        input [7:0] tile_id;
        input [3:0] px;
        input [3:0] py;
        reg [2:0] text_row;
        reg [2:0] text_col;
        reg [4:0] text_bits;
        begin
            if (tile_id >= 8'h20 && tile_id <= 8'h5a) begin
                if (px >= 4'd5 && px <= 4'd9 && py >= 4'd4 && py <= 4'd10) begin
                    text_row = py - 4'd4;
                    text_col = px - 4'd5;
                    text_bits = font_row(tile_id, text_row);
                    tile_pixel = text_bits[4 - text_col] ? 4'hf : 4'h0;
                end else begin
                    tile_pixel = 4'h0;
                end
            end else begin
                case (tile_id)
                    4'h0: tile_pixel = 4'h0;
                    4'h1: tile_pixel = ((px[3:2] ^ py[3:2]) == 2'b00) ? 4'h1 : 4'h2;
                    4'h2: tile_pixel = ((px == 4'd0) || (py == 4'd0) ||
                                        (px == 4'd15) || (py == 4'd15)) ? 4'he :
                                       (((px[0] ^ py[0]) != 1'b0) ? 4'hd : 4'h3);
                    4'h3: tile_pixel = ((px > 4'd5 && px < 4'd10 && py < 4'd12) ||
                                        (py > 4'd11)) ? 4'h6 : 4'h5;
                    4'h4: tile_pixel = ((px >= 4'd6 && px <= 4'd9) ||
                                        (py >= 4'd6 && py <= 4'd9)) ? 4'he : 4'hc;
                    4'h5: tile_pixel = (((px > 4'd3 && px < 4'd12 && py > 4'd2 && py < 4'd13) &&
                                         ((px < 4'd5 || px > 4'd10) || py < 4'd5 || py > 4'd10)) ? 4'h8 :
                                        ((px > 4'd5 && px < 4'd10 && py > 4'd5 && py < 4'd12) ? 4'h9 : 4'h0));
                    4'h6: tile_pixel = ((px > 4'd2 && px < 4'd13 && py > 4'd2 && py < 4'd13) ?
                                        (((py == 4'd6 || py == 4'd7) && (px == 4'd5 || px == 4'd10)) ? 4'h0 : 4'h4) : 4'h0);
                    4'h7: tile_pixel = ((px + py > 4'd10 && px + py < 5'd20 &&
                                         px > 4'd3 && px < 4'd12 && py > 4'd3 && py < 4'd12) ? 4'ha : 4'h0);
                    4'h8: tile_pixel = ((px > 4'd5 && px < 4'd10 && py > 4'd5 && py < 4'd10) ? 4'hf :
                                        (((px > 4'd4 && px < 4'd11 && py > 4'd4 && py < 4'd11) ||
                                          (px == 4'd11 && py > 4'd6 && py < 4'd9) ||
                                          (py == 4'd11 && px > 4'd6 && px < 4'd9)) ? 4'h6 :
                                        (((px == py || px + py == 4'd15) && px > 4'd2 && px < 4'd13) ? 4'h5 : 4'h0)));
                    8'h10: tile_pixel = ((px >= 4'd6 && px <= 4'd8 && py >= 4'd6 && py <= 4'd8) ? 4'hb :
                                         ((px >= 4'd5 && px <= 4'd9 && py >= 4'd5 && py <= 4'd9) ? 4'hf : 4'h0));
                    4'h9: tile_pixel = (px > 4'd1 && px < 4'd14 && py > 4'd3 && py < 4'd12) ? 4'h4 : 4'hd;
                    4'ha: tile_pixel = (px > 4'd1 && px < 4'd8 && py > 4'd3 && py < 4'd12) ? 4'h4 : 4'hd;
                    4'hb: tile_pixel = (px > 4'd1 && px < 4'd14 && py > 4'd3 && py < 4'd12) ? 4'h8 : 4'hd;
                    4'hc: tile_pixel = (px > 4'd1 && px < 4'd8 && py > 4'd3 && py < 4'd12) ? 4'h8 : 4'hd;
                    4'hd: tile_pixel = ((px == 4'd1 || px == 4'd14) && py > 4'd3 && py < 4'd12) ||
                                       ((py == 4'd3 || py == 4'd12) && px > 4'd1 && px < 4'd14) ? 4'hd : 4'h0;
                    4'he: tile_pixel = ((px == 4'd0) || (py == 4'd0) ||
                                        (px == 4'd15) || (py == 4'd15)) ? 4'h3 : 4'h1;
                    4'hf: tile_pixel = (px > 4'd3 && px < 4'd11 && py > 4'd3 && py < 4'd12 &&
                                        (px < py + 4'd2) && (px + py > 4'd9)) ? 4'hf : 4'h0;
                    default: tile_pixel = ((px[3] ^ py[3]) ? tile_id[3:0] : 4'h0);
                endcase
            end
        end
    endfunction
endmodule
