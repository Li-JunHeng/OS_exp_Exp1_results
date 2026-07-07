`timescale 1ns / 1ps
`include "ctrl_encode_def.v"

module dm(
    input         clk,
    input         DMWr,
    input  [31:0] addr,
    input  [31:0] din,
    input  [2:0]  dm_ctrl,
    output [31:0] dout
);
    reg [7:0] dmem[0:511];

    wire [8:0] base = {addr[8:2], 2'b00};
    wire [8:0] byte_addr = addr[8:0];
    wire [31:0] word = {dmem[base + 9'd3], dmem[base + 9'd2],
                        dmem[base + 9'd1], dmem[base]};
    wire [15:0] half = addr[1] ? word[31:16] : word[15:0];
    wire [7:0] mem_byte = word[{addr[1:0], 3'b000} +: 8];

    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1)
            dmem[i] = 8'b0;
    end

    always @(posedge clk) begin
        if (DMWr) begin
            case (dm_ctrl)
                `dm_byte, `dm_byte_unsigned: begin
                    dmem[byte_addr] <= din[7:0];
                    $display("dmem[0x%8X] byte = 0x%02X,", byte_addr, din[7:0]);
                end
                `dm_halfword, `dm_halfword_unsigned: begin
                    dmem[{addr[8:1], 1'b0}] <= din[7:0];
                    dmem[{addr[8:1], 1'b0} + 9'd1] <= din[15:8];
                    $display("dmem[0x%8X] half = 0x%04X,", {addr[8:1], 1'b0}, din[15:0]);
                end
                default: begin
                    dmem[base] <= din[7:0];
                    dmem[base + 9'd1] <= din[15:8];
                    dmem[base + 9'd2] <= din[23:16];
                    dmem[base + 9'd3] <= din[31:24];
                    $display("dmem[0x%8X] = 0x%8X,", base, din);
                end
            endcase
        end
    end

    assign dout = (dm_ctrl == `dm_byte) ? {{24{mem_byte[7]}}, mem_byte} :
                  (dm_ctrl == `dm_byte_unsigned) ? {24'b0, mem_byte} :
                  (dm_ctrl == `dm_halfword) ? {{16{half[15]}}, half} :
                  (dm_ctrl == `dm_halfword_unsigned) ? {16'b0, half} :
                  word;
endmodule
