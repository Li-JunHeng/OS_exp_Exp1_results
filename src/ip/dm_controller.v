`timescale 1ns / 1ps
module dm_controller(
    input         mem_w,
    input  [31:0] Addr_in,
    input  [31:0] Data_write,
    input  [2:0]  dm_ctrl,
    input  [31:0] Data_read_from_dm,
    output [31:0] Data_read,
    output [31:0] Data_write_to_dm,
    output [3:0]  wea_mem
);
    localparam [2:0] DM_WORD              = 3'b000;
    localparam [2:0] DM_HALFWORD          = 3'b001;
    localparam [2:0] DM_HALFWORD_UNSIGNED = 3'b010;
    localparam [2:0] DM_BYTE              = 3'b011;
    localparam [2:0] DM_BYTE_UNSIGNED     = 3'b100;

    wire [1:0] byte_offset = Addr_in[1:0];
    wire       half_offset = Addr_in[1];

    wire [7:0] read_byte =
        (byte_offset == 2'd0) ? Data_read_from_dm[7:0] :
        (byte_offset == 2'd1) ? Data_read_from_dm[15:8] :
        (byte_offset == 2'd2) ? Data_read_from_dm[23:16] :
                                Data_read_from_dm[31:24];

    wire [15:0] read_half = half_offset ? Data_read_from_dm[31:16] :
                                          Data_read_from_dm[15:0];

    assign Data_read =
        (dm_ctrl == DM_BYTE)              ? {{24{read_byte[7]}}, read_byte} :
        (dm_ctrl == DM_BYTE_UNSIGNED)     ? {24'b0, read_byte} :
        (dm_ctrl == DM_HALFWORD)          ? {{16{read_half[15]}}, read_half} :
        (dm_ctrl == DM_HALFWORD_UNSIGNED) ? {16'b0, read_half} :
                                             Data_read_from_dm;

    assign Data_write_to_dm =
        (dm_ctrl == DM_BYTE || dm_ctrl == DM_BYTE_UNSIGNED) ?
            ((byte_offset == 2'd0) ? {24'b0, Data_write[7:0]} :
             (byte_offset == 2'd1) ? {16'b0, Data_write[7:0], 8'b0} :
             (byte_offset == 2'd2) ? {8'b0, Data_write[7:0], 16'b0} :
                                     {Data_write[7:0], 24'b0}) :
        (dm_ctrl == DM_HALFWORD || dm_ctrl == DM_HALFWORD_UNSIGNED) ?
            (half_offset ? {Data_write[15:0], 16'b0} :
                           {16'b0, Data_write[15:0]}) :
            Data_write;

    assign wea_mem = mem_w ?
        ((dm_ctrl == DM_BYTE || dm_ctrl == DM_BYTE_UNSIGNED) ?
            ((byte_offset == 2'd0) ? 4'b0001 :
             (byte_offset == 2'd1) ? 4'b0010 :
             (byte_offset == 2'd2) ? 4'b0100 :
                                     4'b1000) :
         (dm_ctrl == DM_HALFWORD || dm_ctrl == DM_HALFWORD_UNSIGNED) ?
            (half_offset ? 4'b1100 : 4'b0011) :
            4'b1111) :
        4'b0000;
endmodule
