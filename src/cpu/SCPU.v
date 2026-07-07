`timescale 1ns / 1ps
`include "ctrl_encode_def.v"

module SCPU(
    input         clk,
    input         reset,
    input  [31:0] inst_in,
    input  [31:0] Data_in,

    output        mem_w,
    output [31:0] PC_out,
    output [31:0] Addr_out,
    output [31:0] Data_out,
    output [2:0]  dm_ctrl,

    input  [4:0]  reg_sel,
    output [31:0] reg_data
);
    localparam [31:0] NOP = 32'h0000_0013;

    reg [31:0] pc_if;

    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_inst;

    reg        id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_pc4;
    reg [31:0] id_ex_rd1;
    reg [31:0] id_ex_rd2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg        id_ex_regwrite;
    reg        id_ex_memwrite;
    reg        id_ex_alusrc;
    reg [1:0]  id_ex_wdsel;
    reg [4:0]  id_ex_aluop;
    reg [2:0]  id_ex_dm_ctrl;
    reg        id_ex_is_branch;
    reg        id_ex_is_jal;
    reg        id_ex_is_jalr;

    reg        ex_mem_valid;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [31:0] ex_mem_pc4;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_regwrite;
    reg        ex_mem_memwrite;
    reg [1:0]  ex_mem_wdsel;
    reg [2:0]  ex_mem_dm_ctrl;

    reg        mem_wb_valid;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_pc4;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_regwrite;
    reg [1:0]  mem_wb_wdsel;

    wire [4:0] id_rs1 = if_id_inst[19:15];
    wire [4:0] id_rs2 = if_id_inst[24:20];
    wire [4:0] id_rd  = if_id_inst[11:7];
    wire [6:0] id_op  = if_id_inst[6:0];
    wire [6:0] id_funct7 = if_id_inst[31:25];
    wire [2:0] id_funct3 = if_id_inst[14:12];

    wire [4:0] id_iimm_shamt = if_id_inst[24:20];
    wire [11:0] id_iimm = if_id_inst[31:20];
    wire [11:0] id_simm = {if_id_inst[31:25], if_id_inst[11:7]};
    wire [11:0] id_bimm = {if_id_inst[31], if_id_inst[7], if_id_inst[30:25], if_id_inst[11:8]};
    wire [19:0] id_uimm = if_id_inst[31:12];
    wire [19:0] id_jimm = {if_id_inst[31], if_id_inst[19:12], if_id_inst[20], if_id_inst[30:21]};

    wire        ctrl_regwrite;
    wire        ctrl_memwrite;
    wire [5:0]  ctrl_extop;
    wire [4:0]  ctrl_aluop;
    wire [2:0]  ctrl_npcop;
    wire        ctrl_alusrc;
    wire [1:0]  ctrl_gprsel;
    wire [1:0]  ctrl_wdsel;
    wire [2:0]  ctrl_dmtype;

    wire [31:0] id_imm;
    wire [31:0] rf_rd1;
    wire [31:0] rf_rd2;
    wire [31:0] wb_data;

    wire id_is_branch = (id_op == 7'b1100011);
    wire id_is_jal    = (id_op == 7'b1101111);
    wire id_is_jalr   = (id_op == 7'b1100111);

    wire id_regwrite = if_id_valid ? ctrl_regwrite : 1'b0;
    wire id_memwrite = if_id_valid ? ctrl_memwrite : 1'b0;
    wire id_alusrc   = if_id_valid ? ctrl_alusrc   : 1'b0;
    wire [1:0] id_wdsel = if_id_valid ? ctrl_wdsel : `WDSel_FromALU;
    wire [4:0] id_aluop = if_id_valid ? ctrl_aluop : `ALUOp_nop;
    wire [2:0] id_dm_ctrl = if_id_valid ? ctrl_dmtype : `dm_word;

    wire [31:0] id_rd1_bypass =
        (mem_wb_regwrite && mem_wb_rd != 5'b0 && mem_wb_rd == id_rs1) ? wb_data : rf_rd1;
    wire [31:0] id_rd2_bypass =
        (mem_wb_regwrite && mem_wb_rd != 5'b0 && mem_wb_rd == id_rs2) ? wb_data : rf_rd2;

    wire [31:0] mem_stage_wb_data =
        (ex_mem_wdsel == `WDSel_FromMEM) ? Data_in :
        (ex_mem_wdsel == `WDSel_FromPC)  ? ex_mem_pc4 :
                                           ex_mem_alu_result;

    wire [31:0] ex_rs1_value =
        (ex_mem_regwrite && ex_mem_rd != 5'b0 && ex_mem_rd == id_ex_rs1) ? mem_stage_wb_data :
        (mem_wb_regwrite && mem_wb_rd != 5'b0 && mem_wb_rd == id_ex_rs1) ? wb_data :
                                                                           id_ex_rd1;
    wire [31:0] ex_rs2_value =
        (ex_mem_regwrite && ex_mem_rd != 5'b0 && ex_mem_rd == id_ex_rs2) ? mem_stage_wb_data :
        (mem_wb_regwrite && mem_wb_rd != 5'b0 && mem_wb_rd == id_ex_rs2) ? wb_data :
                                                                           id_ex_rd2;
    wire [31:0] ex_alu_b = id_ex_alusrc ? id_ex_imm : ex_rs2_value;
    wire [31:0] ex_alu_result;
    wire        ex_zero;

    wire        ex_take_branch = id_ex_valid &&
                                 ((id_ex_is_branch && ex_zero) ||
                                  id_ex_is_jal ||
                                  id_ex_is_jalr);
    wire [31:0] ex_branch_target = id_ex_is_jalr ? {ex_alu_result[31:1], 1'b0} :
                                                    (id_ex_pc + id_ex_imm);

    assign PC_out = pc_if;
    assign mem_w = ex_mem_valid && ex_mem_memwrite;
    assign Addr_out = ex_mem_alu_result;
    assign Data_out = ex_mem_store_data;
    assign dm_ctrl = ex_mem_dm_ctrl;

    assign wb_data =
        (mem_wb_wdsel == `WDSel_FromMEM) ? mem_wb_mem_data :
        (mem_wb_wdsel == `WDSel_FromPC)  ? mem_wb_pc4 :
                                           mem_wb_alu_result;

    ctrl U_ctrl(
        .Op(id_op),
        .Funct7(id_funct7),
        .Funct3(id_funct3),
        .Zero(1'b0),
        .RegWrite(ctrl_regwrite),
        .MemWrite(ctrl_memwrite),
        .EXTOp(ctrl_extop),
        .ALUOp(ctrl_aluop),
        .NPCOp(ctrl_npcop),
        .ALUSrc(ctrl_alusrc),
        .GPRSel(ctrl_gprsel),
        .WDSel(ctrl_wdsel),
        .DMType(ctrl_dmtype)
    );

    EXT U_EXT(
        .iimm_shamt(id_iimm_shamt),
        .iimm(id_iimm),
        .simm(id_simm),
        .bimm(id_bimm),
        .uimm(id_uimm),
        .jimm(id_jimm),
        .EXTOp(ctrl_extop),
        .immout(id_imm)
    );

    RF U_RF(
        .clk(clk),
        .rst(reset),
        .RFWr(mem_wb_valid && mem_wb_regwrite),
        .A1(id_rs1),
        .A2(id_rs2),
        .A3(mem_wb_rd),
        .WD(wb_data),
        .reg_sel(reg_sel),
        .RD1(rf_rd1),
        .RD2(rf_rd2),
        .reg_data(reg_data)
    );

    alu U_alu(
        .A(ex_rs1_value),
        .B(ex_alu_b),
        .ALUOp(id_ex_aluop),
        .C(ex_alu_result),
        .Zero(ex_zero),
        .PC(id_ex_pc)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_if <= 32'b0;

            if_id_valid <= 1'b0;
            if_id_pc <= 32'b0;
            if_id_inst <= NOP;

            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'b0;
            id_ex_pc4 <= 32'b0;
            id_ex_rd1 <= 32'b0;
            id_ex_rd2 <= 32'b0;
            id_ex_imm <= 32'b0;
            id_ex_rs1 <= 5'b0;
            id_ex_rs2 <= 5'b0;
            id_ex_rd <= 5'b0;
            id_ex_regwrite <= 1'b0;
            id_ex_memwrite <= 1'b0;
            id_ex_alusrc <= 1'b0;
            id_ex_wdsel <= `WDSel_FromALU;
            id_ex_aluop <= `ALUOp_nop;
            id_ex_dm_ctrl <= `dm_word;
            id_ex_is_branch <= 1'b0;
            id_ex_is_jal <= 1'b0;
            id_ex_is_jalr <= 1'b0;

            ex_mem_valid <= 1'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_pc4 <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_regwrite <= 1'b0;
            ex_mem_memwrite <= 1'b0;
            ex_mem_wdsel <= `WDSel_FromALU;
            ex_mem_dm_ctrl <= `dm_word;

            mem_wb_valid <= 1'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data <= 32'b0;
            mem_wb_pc4 <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_regwrite <= 1'b0;
            mem_wb_wdsel <= `WDSel_FromALU;
        end else begin
            mem_wb_valid <= ex_mem_valid;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= Data_in;
            mem_wb_pc4 <= ex_mem_pc4;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_regwrite <= ex_mem_regwrite;
            mem_wb_wdsel <= ex_mem_wdsel;

            ex_mem_valid <= id_ex_valid;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_store_data <= ex_rs2_value;
            ex_mem_pc4 <= id_ex_pc4;
            ex_mem_rd <= id_ex_rd;
            ex_mem_regwrite <= id_ex_regwrite;
            ex_mem_memwrite <= id_ex_memwrite;
            ex_mem_wdsel <= id_ex_wdsel;
            ex_mem_dm_ctrl <= id_ex_dm_ctrl;

            pc_if <= ex_take_branch ? ex_branch_target : (pc_if + 32'd4);

            if (ex_take_branch) begin
                if_id_valid <= 1'b0;
                if_id_pc <= 32'b0;
                if_id_inst <= NOP;

                id_ex_valid <= 1'b0;
                id_ex_pc <= 32'b0;
                id_ex_pc4 <= 32'b0;
                id_ex_rd1 <= 32'b0;
                id_ex_rd2 <= 32'b0;
                id_ex_imm <= 32'b0;
                id_ex_rs1 <= 5'b0;
                id_ex_rs2 <= 5'b0;
                id_ex_rd <= 5'b0;
                id_ex_regwrite <= 1'b0;
                id_ex_memwrite <= 1'b0;
                id_ex_alusrc <= 1'b0;
                id_ex_wdsel <= `WDSel_FromALU;
                id_ex_aluop <= `ALUOp_nop;
                id_ex_dm_ctrl <= `dm_word;
                id_ex_is_branch <= 1'b0;
                id_ex_is_jal <= 1'b0;
                id_ex_is_jalr <= 1'b0;
            end else begin
                if_id_valid <= 1'b1;
                if_id_pc <= pc_if;
                if_id_inst <= inst_in;

                id_ex_valid <= if_id_valid;
                id_ex_pc <= if_id_pc;
                id_ex_pc4 <= if_id_pc + 32'd4;
                id_ex_rd1 <= id_rd1_bypass;
                id_ex_rd2 <= id_rd2_bypass;
                id_ex_imm <= id_imm;
                id_ex_rs1 <= id_rs1;
                id_ex_rs2 <= id_rs2;
                id_ex_rd <= id_rd;
                id_ex_regwrite <= id_regwrite;
                id_ex_memwrite <= id_memwrite;
                id_ex_alusrc <= id_alusrc;
                id_ex_wdsel <= id_wdsel;
                id_ex_aluop <= id_aluop;
                id_ex_dm_ctrl <= id_dm_ctrl;
                id_ex_is_branch <= if_id_valid && id_is_branch;
                id_ex_is_jal <= if_id_valid && id_is_jal;
                id_ex_is_jalr <= if_id_valid && id_is_jalr;
            end
        end
    end
endmodule
