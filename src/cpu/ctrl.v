`timescale 1ns / 1ps
`include "ctrl_encode_def.v"

module ctrl(
    input  [6:0] Op,
    input  [6:0] Funct7,
    input  [2:0] Funct3,
    input        Zero,
    output       RegWrite,
    output       MemWrite,
    output [5:0] EXTOp,
    output [4:0] ALUOp,
    output [2:0] NPCOp,
    output       ALUSrc,
    output [1:0] GPRSel,
    output [1:0] WDSel,
    output [2:0] DMType
);
    wire opcode_load   = (Op == 7'b0000011);
    wire opcode_itype  = (Op == 7'b0010011);
    wire opcode_auipc  = (Op == 7'b0010111);
    wire opcode_store  = (Op == 7'b0100011);
    wire opcode_rtype  = (Op == 7'b0110011);
    wire opcode_lui    = (Op == 7'b0110111);
    wire opcode_branch = (Op == 7'b1100011);
    wire opcode_jalr   = (Op == 7'b1100111);
    wire opcode_jal    = (Op == 7'b1101111);

    wire i_add  = opcode_rtype && Funct3 == 3'b000 && Funct7 == 7'b0000000;
    wire i_sub  = opcode_rtype && Funct3 == 3'b000 && Funct7 == 7'b0100000;
    wire i_sll  = opcode_rtype && Funct3 == 3'b001 && Funct7 == 7'b0000000;
    wire i_slt  = opcode_rtype && Funct3 == 3'b010 && Funct7 == 7'b0000000;
    wire i_sltu = opcode_rtype && Funct3 == 3'b011 && Funct7 == 7'b0000000;
    wire i_xor  = opcode_rtype && Funct3 == 3'b100 && Funct7 == 7'b0000000;
    wire i_srl  = opcode_rtype && Funct3 == 3'b101 && Funct7 == 7'b0000000;
    wire i_sra  = opcode_rtype && Funct3 == 3'b101 && Funct7 == 7'b0100000;
    wire i_or   = opcode_rtype && Funct3 == 3'b110 && Funct7 == 7'b0000000;
    wire i_and  = opcode_rtype && Funct3 == 3'b111 && Funct7 == 7'b0000000;

    wire i_addi  = opcode_itype && Funct3 == 3'b000;
    wire i_slli  = opcode_itype && Funct3 == 3'b001 && Funct7 == 7'b0000000;
    wire i_slti  = opcode_itype && Funct3 == 3'b010;
    wire i_sltiu = opcode_itype && Funct3 == 3'b011;
    wire i_xori  = opcode_itype && Funct3 == 3'b100;
    wire i_srli  = opcode_itype && Funct3 == 3'b101 && Funct7 == 7'b0000000;
    wire i_srai  = opcode_itype && Funct3 == 3'b101 && Funct7 == 7'b0100000;
    wire i_ori   = opcode_itype && Funct3 == 3'b110;
    wire i_andi  = opcode_itype && Funct3 == 3'b111;

    wire i_lb  = opcode_load && Funct3 == 3'b000;
    wire i_lh  = opcode_load && Funct3 == 3'b001;
    wire i_lw  = opcode_load && Funct3 == 3'b010;
    wire i_lbu = opcode_load && Funct3 == 3'b100;
    wire i_lhu = opcode_load && Funct3 == 3'b101;

    wire i_sb = opcode_store && Funct3 == 3'b000;
    wire i_sh = opcode_store && Funct3 == 3'b001;
    wire i_sw = opcode_store && Funct3 == 3'b010;

    wire i_beq  = opcode_branch && Funct3 == 3'b000;
    wire i_bne  = opcode_branch && Funct3 == 3'b001;
    wire i_blt  = opcode_branch && Funct3 == 3'b100;
    wire i_bge  = opcode_branch && Funct3 == 3'b101;
    wire i_bltu = opcode_branch && Funct3 == 3'b110;
    wire i_bgeu = opcode_branch && Funct3 == 3'b111;

    assign RegWrite = opcode_rtype | opcode_itype | opcode_load | opcode_lui |
                      opcode_auipc | opcode_jal | opcode_jalr;
    assign MemWrite = opcode_store;
    assign ALUSrc   = opcode_itype | opcode_load | opcode_store |
                      opcode_lui | opcode_auipc | opcode_jalr;

    assign EXTOp = (i_slli | i_srli | i_srai) ? `EXT_CTRL_ITYPE_SHAMT :
                   (opcode_itype | opcode_load | opcode_jalr) ? `EXT_CTRL_ITYPE :
                   opcode_store ? `EXT_CTRL_STYPE :
                   opcode_branch ? `EXT_CTRL_BTYPE :
                   (opcode_lui | opcode_auipc) ? `EXT_CTRL_UTYPE :
                   opcode_jal ? `EXT_CTRL_JTYPE :
                   6'b000000;

    assign WDSel = opcode_load ? `WDSel_FromMEM :
                   (opcode_jal | opcode_jalr) ? `WDSel_FromPC :
                   `WDSel_FromALU;
    assign GPRSel = `GPRSel_RD;

    assign NPCOp = (opcode_branch && Zero) ? `NPC_BRANCH :
                   opcode_jal ? `NPC_JUMP :
                   opcode_jalr ? `NPC_JALR :
                   `NPC_PLUS4;

    assign ALUOp = opcode_lui ? `ALUOp_lui :
                   (opcode_auipc) ? `ALUOp_auipc :
                   (i_sub | i_beq) ? `ALUOp_sub :
                   (i_bne) ? `ALUOp_bne :
                   (i_blt) ? `ALUOp_blt :
                   (i_bge) ? `ALUOp_bge :
                   (i_bltu) ? `ALUOp_bltu :
                   (i_bgeu) ? `ALUOp_bgeu :
                   (i_slt | i_slti) ? `ALUOp_slt :
                   (i_sltu | i_sltiu) ? `ALUOp_sltu :
                   (i_xor | i_xori) ? `ALUOp_xor :
                   (i_or | i_ori) ? `ALUOp_or :
                   (i_and | i_andi) ? `ALUOp_and :
                   (i_sll | i_slli) ? `ALUOp_sll :
                   (i_srl | i_srli) ? `ALUOp_srl :
                   (i_sra | i_srai) ? `ALUOp_sra :
                   (i_add | i_addi | opcode_load | opcode_store | opcode_jalr) ? `ALUOp_add :
                   `ALUOp_nop;

    assign DMType = (i_lh | i_sh) ? `dm_halfword :
                    i_lhu ? `dm_halfword_unsigned :
                    (i_lb | i_sb) ? `dm_byte :
                    i_lbu ? `dm_byte_unsigned :
                    `dm_word;
endmodule
