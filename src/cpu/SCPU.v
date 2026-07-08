`timescale 1ns / 1ps
`include "ctrl_encode_def.v"

module SCPU #(
    parameter [31:0] RESET_MSTATUS = 32'h0000_0008,
    parameter [31:0] RESET_MIE     = 32'h0000_0888,
    parameter [31:0] RESET_MTVEC   = 32'h0000_0080
)(
    input         clk,
    input         reset,
    input         software_irq,
    input         timer_irq,
    input         external_irq,
    input         uart_irq,
    input         gpio_irq,
    input         spi_irq,
    input         i2c_irq,
    input         keyboard_irq,
    input  [31:0] inst_in,
    input  [31:0] Data_in,

    output        mem_r,
    output        mem_w,
    output [31:0] PC_out,
    output [31:0] Addr_out,
    output [31:0] Data_out,
    output [2:0]  dm_ctrl,

    input  [4:0]  reg_sel,
    output [31:0] reg_data
);
    localparam [31:0] NOP = 32'h0000_0013;

    localparam [11:0] CSR_MSTATUS = 12'h300;
    localparam [11:0] CSR_MIE     = 12'h304;
    localparam [11:0] CSR_MTVEC   = 12'h305;
    localparam [11:0] CSR_SATP    = 12'h180;
    localparam [11:0] CSR_MEPC    = 12'h341;
    localparam [11:0] CSR_MCAUSE  = 12'h342;
    localparam [11:0] CSR_MTVAL   = 12'h343;
    localparam [11:0] CSR_MIP     = 12'h344;
    localparam [11:0] CSR_TLBIDX  = 12'h7c0;
    localparam [11:0] CSR_TLBVPN  = 12'h7c1;
    localparam [11:0] CSR_TLBPPN  = 12'h7c2;
    localparam [11:0] CSR_TLBFLAGS = 12'h7c3;
    localparam [11:0] CSR_PLIC_PENDING = 12'h7d0;
    localparam [11:0] CSR_PLIC_ENABLE  = 12'h7d1;
    localparam [11:0] CSR_PLIC_CLAIM   = 12'h7d2;
    localparam [11:0] CSR_PLIC_FORCE   = 12'h7d3;

    localparam [2:0] PLIC_ID_NONE = 3'd0;
    localparam [2:0] PLIC_ID_UART = 3'd1;
    localparam [2:0] PLIC_ID_GPIO = 3'd2;
    localparam [2:0] PLIC_ID_SPI  = 3'd3;
    localparam [2:0] PLIC_ID_I2C  = 3'd4;
    localparam [2:0] PLIC_ID_KEYBOARD = 3'd5;

    localparam [31:0] CAUSE_INST_ACCESS_FAULT = 32'd1;
    localparam [31:0] CAUSE_ILLEGAL_INST      = 32'd2;
    localparam [31:0] CAUSE_BREAKPOINT        = 32'd3;
    localparam [31:0] CAUSE_LOAD_ACCESS_FAULT = 32'd5;
    localparam [31:0] CAUSE_STORE_ACCESS_FAULT = 32'd7;
    localparam [31:0] CAUSE_ECALL_M           = 32'd11;
    localparam [31:0] CAUSE_INST_PAGE_FAULT   = 32'd12;
    localparam [31:0] CAUSE_LOAD_PAGE_FAULT   = 32'd13;
    localparam [31:0] CAUSE_STORE_PAGE_FAULT  = 32'd15;
    localparam [31:0] CAUSE_MSI               = 32'h8000_0003;
    localparam [31:0] CAUSE_MTI               = 32'h8000_0007;
    localparam [31:0] CAUSE_MEI               = 32'h8000_000b;

    localparam [1:0] CSR_CMD_WRITE = 2'b01;
    localparam [1:0] CSR_CMD_SET   = 2'b10;
    localparam [1:0] CSR_CMD_CLEAR = 2'b11;

    reg [31:0] pc_if;

    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_inst;
    reg        if_id_inst_trap;
    reg [31:0] if_id_inst_trap_cause;
    reg [31:0] if_id_inst_trap_tval;

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
    reg        id_ex_is_mret;
    reg        id_ex_is_load;
    reg        id_ex_is_store;
    reg        id_ex_exception;
    reg [31:0] id_ex_exception_cause;
    reg [31:0] id_ex_exception_tval;
    reg        id_ex_csr_write;
    reg [1:0]  id_ex_csr_cmd;
    reg [11:0] id_ex_csr_addr;
    reg [31:0] id_ex_csr_wdata;
    reg [31:0] id_ex_csr_rdata;

    reg        ex_mem_valid;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [31:0] ex_mem_pc4;
    reg [31:0] ex_mem_csr_rdata;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_regwrite;
    reg        ex_mem_memwrite;
    reg        ex_mem_memread;
    reg [1:0]  ex_mem_wdsel;
    reg [2:0]  ex_mem_dm_ctrl;
    reg        ex_mem_csr_write;
    reg [1:0]  ex_mem_csr_cmd;
    reg [11:0] ex_mem_csr_addr;
    reg [31:0] ex_mem_csr_wdata;

    reg        mem_wb_valid;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_pc4;
    reg [31:0] mem_wb_csr_rdata;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_regwrite;
    reg [1:0]  mem_wb_wdsel;
    reg        mem_wb_csr_write;
    reg [1:0]  mem_wb_csr_cmd;
    reg [11:0] mem_wb_csr_addr;
    reg [31:0] mem_wb_csr_wdata;

    reg [31:0] csr_mstatus;
    reg [31:0] csr_mie;
    reg [31:0] csr_mtvec;
    reg [31:0] csr_mepc;
    reg [31:0] csr_mcause;

    reg [31:0] csr_mtval;
    reg [31:0] csr_satp;
    reg        csr_mip_msip;
    reg [1:0]  csr_tlbidx;

    reg [19:0] tlb_vpn [0:3];
    reg [19:0] tlb_ppn [0:3];
    reg [3:0]  tlb_valid;
    reg [3:0]  tlb_read;
    reg [3:0]  tlb_write;
    reg [3:0]  tlb_exec;

    reg software_irq_meta;
    reg software_irq_sync;
    reg timer_irq_meta;
    reg timer_irq_sync;
    reg external_irq_meta;
    reg external_irq_sync;
    reg uart_irq_meta;
    reg uart_irq_sync;
    reg gpio_irq_meta;
    reg gpio_irq_sync;
    reg spi_irq_meta;
    reg spi_irq_sync;
    reg i2c_irq_meta;
    reg i2c_irq_sync;
    reg keyboard_irq_meta;
    reg keyboard_irq_sync;
    reg [5:0] plic_pending;
    reg [5:0] plic_enable;
    reg irq_drain;
    reg [31:0] irq_drain_cause;

    integer tlb_i;
    integer tlb_reset_i;

    wire [4:0] id_rs1 = if_id_inst[19:15];
    wire [4:0] id_rs2 = if_id_inst[24:20];
    wire [4:0] id_rd  = if_id_inst[11:7];
    wire [6:0] id_op  = if_id_inst[6:0];
    wire [6:0] id_funct7 = if_id_inst[31:25];
    wire [2:0] id_funct3 = if_id_inst[14:12];
    wire [11:0] id_csr_addr = if_id_inst[31:20];

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
    wire id_is_system = (id_op == 7'b1110011);
    wire id_is_load   = (id_op == 7'b0000011);
    wire id_is_store  = (id_op == 7'b0100011);
    wire id_is_csr    = id_is_system && (id_funct3 != 3'b000);
    wire id_is_mret   = id_is_system && (if_id_inst == 32'h3020_0073);
    wire id_is_ecall  = id_is_system && (if_id_inst == 32'h0000_0073);
    wire id_is_ebreak = id_is_system && (if_id_inst == 32'h0010_0073);
    wire id_csr_imm   = id_funct3[2];
    wire id_csr_addr_valid = (id_csr_addr == CSR_MSTATUS) ||
                             (id_csr_addr == CSR_MIE) ||
                             (id_csr_addr == CSR_MTVEC) ||
                             (id_csr_addr == CSR_SATP) ||
                             (id_csr_addr == CSR_MEPC) ||
                             (id_csr_addr == CSR_MCAUSE) ||
                             (id_csr_addr == CSR_MTVAL) ||
                             (id_csr_addr == CSR_MIP) ||
                             (id_csr_addr == CSR_TLBIDX) ||
                             (id_csr_addr == CSR_TLBVPN) ||
                             (id_csr_addr == CSR_TLBPPN) ||
                             (id_csr_addr == CSR_TLBFLAGS) ||
                             (id_csr_addr == CSR_PLIC_PENDING) ||
                             (id_csr_addr == CSR_PLIC_ENABLE) ||
                             (id_csr_addr == CSR_PLIC_CLAIM) ||
                             (id_csr_addr == CSR_PLIC_FORCE);
    wire [1:0] id_csr_cmd = (id_funct3[1:0] == 2'b01) ? CSR_CMD_WRITE :
                            (id_funct3[1:0] == 2'b10) ? CSR_CMD_SET :
                                                         CSR_CMD_CLEAR;
    wire id_csr_write = id_is_csr &&
                        ((id_funct3[1:0] == 2'b01) || (id_rs1 != 5'b0));
    wire [31:0] id_csr_wdata;
    wire [31:0] id_csr_rdata = csr_read_data(id_csr_addr);

    wire id_rtype_valid = (id_op == 7'b0110011) &&
                          (((id_funct3 == 3'b000) && (id_funct7 == 7'b0000000 || id_funct7 == 7'b0100000)) ||
                           ((id_funct3 == 3'b001) && id_funct7 == 7'b0000000) ||
                           ((id_funct3 == 3'b010) && id_funct7 == 7'b0000000) ||
                           ((id_funct3 == 3'b011) && id_funct7 == 7'b0000000) ||
                           ((id_funct3 == 3'b100) && id_funct7 == 7'b0000000) ||
                           ((id_funct3 == 3'b101) && (id_funct7 == 7'b0000000 || id_funct7 == 7'b0100000)) ||
                           ((id_funct3 == 3'b110) && id_funct7 == 7'b0000000) ||
                           ((id_funct3 == 3'b111) && id_funct7 == 7'b0000000));
    wire id_itype_valid = (id_op == 7'b0010011) &&
                          ((id_funct3 == 3'b000) ||
                           (id_funct3 == 3'b010) ||
                           (id_funct3 == 3'b011) ||
                           (id_funct3 == 3'b100) ||
                           (id_funct3 == 3'b110) ||
                           (id_funct3 == 3'b111) ||
                           ((id_funct3 == 3'b001) && id_funct7 == 7'b0000000) ||
                           ((id_funct3 == 3'b101) && (id_funct7 == 7'b0000000 || id_funct7 == 7'b0100000)));
    wire id_load_valid = id_is_load &&
                         (id_funct3 == 3'b000 || id_funct3 == 3'b001 ||
                          id_funct3 == 3'b010 || id_funct3 == 3'b100 ||
                          id_funct3 == 3'b101);
    wire id_store_valid = id_is_store &&
                          (id_funct3 == 3'b000 || id_funct3 == 3'b001 ||
                           id_funct3 == 3'b010);
    wire id_branch_valid = id_is_branch &&
                           (id_funct3 == 3'b000 || id_funct3 == 3'b001 ||
                            id_funct3 == 3'b100 || id_funct3 == 3'b101 ||
                            id_funct3 == 3'b110 || id_funct3 == 3'b111);
    wire id_jalr_valid = id_is_jalr && id_funct3 == 3'b000;
    wire id_csr_valid = id_is_csr && id_funct3[1:0] != 2'b00 && id_csr_addr_valid;
    wire id_known_instruction = id_rtype_valid || id_itype_valid || id_load_valid ||
                                id_store_valid || id_branch_valid || id_jalr_valid ||
                                id_is_jal || (id_op == 7'b0110111) ||
                                (id_op == 7'b0010111) || id_csr_valid ||
                                id_is_mret || id_is_ecall || id_is_ebreak;

    wire id_illegal_instruction = if_id_valid && !if_id_inst_trap && !id_known_instruction;
    wire id_exception = if_id_valid &&
                        (if_id_inst_trap || id_illegal_instruction ||
                         id_is_ebreak || id_is_ecall);
    wire [31:0] id_exception_cause =
        if_id_inst_trap        ? if_id_inst_trap_cause :
        id_illegal_instruction  ? CAUSE_ILLEGAL_INST :
        id_is_ebreak           ? CAUSE_BREAKPOINT :
                                  CAUSE_ECALL_M;
    wire [31:0] id_exception_tval =
        if_id_inst_trap        ? if_id_inst_trap_tval :
        id_illegal_instruction  ? if_id_inst :
                                  32'b0;

    wire id_regwrite = (if_id_valid && !id_exception) ? (ctrl_regwrite || id_is_csr) : 1'b0;
    wire id_memwrite = (if_id_valid && !id_exception) ? ctrl_memwrite : 1'b0;
    wire id_alusrc   = if_id_valid ? ctrl_alusrc   : 1'b0;
    wire [1:0] id_wdsel = !if_id_valid ? `WDSel_FromALU :
                          id_is_csr   ? `WDSel_FromCSR :
                                        ctrl_wdsel;
    wire [4:0] id_aluop = if_id_valid ? ctrl_aluop : `ALUOp_nop;
    wire [2:0] id_dm_ctrl = if_id_valid ? ctrl_dmtype : `dm_word;

    wire [31:0] id_rd1_bypass =
        (mem_wb_regwrite && mem_wb_rd != 5'b0 && mem_wb_rd == id_rs1) ? wb_data : rf_rd1;
    wire [31:0] id_rd2_bypass =
        (mem_wb_regwrite && mem_wb_rd != 5'b0 && mem_wb_rd == id_rs2) ? wb_data : rf_rd2;
    assign id_csr_wdata = id_csr_imm ? {27'b0, id_rs1} : id_rd1_bypass;

    wire [31:0] mem_stage_wb_data =
        (ex_mem_wdsel == `WDSel_FromMEM) ? Data_in :
        (ex_mem_wdsel == `WDSel_FromPC)  ? ex_mem_pc4 :
        (ex_mem_wdsel == `WDSel_FromCSR) ? ex_mem_csr_rdata :
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
    wire        ex_mret = id_ex_valid && id_ex_is_mret;
    wire [31:0] ex_branch_target = id_ex_is_jalr ? {ex_alu_result[31:1], 1'b0} :
                                                    (id_ex_pc + id_ex_imm);

    wire mmu_enabled = csr_satp[31];

    reg        if_tlb_hit;
    reg        if_tlb_exec;
    reg [19:0] if_tlb_ppn;
    reg        data_tlb_hit;
    reg        data_tlb_read;
    reg        data_tlb_write;
    reg [19:0] data_tlb_ppn;

    always @(*) begin
        if_tlb_hit = 1'b0;
        if_tlb_exec = 1'b0;
        if_tlb_ppn = 20'b0;
        data_tlb_hit = 1'b0;
        data_tlb_read = 1'b0;
        data_tlb_write = 1'b0;
        data_tlb_ppn = 20'b0;

        for (tlb_i = 0; tlb_i < 4; tlb_i = tlb_i + 1) begin
            if (tlb_valid[tlb_i] && tlb_vpn[tlb_i] == pc_if[31:12] && !if_tlb_hit) begin
                if_tlb_hit = 1'b1;
                if_tlb_exec = tlb_exec[tlb_i];
                if_tlb_ppn = tlb_ppn[tlb_i];
            end
            if (tlb_valid[tlb_i] && tlb_vpn[tlb_i] == ex_alu_result[31:12] && !data_tlb_hit) begin
                data_tlb_hit = 1'b1;
                data_tlb_read = tlb_read[tlb_i];
                data_tlb_write = tlb_write[tlb_i];
                data_tlb_ppn = tlb_ppn[tlb_i];
            end
        end
    end

    wire [31:0] if_phys_addr = mmu_enabled ? {if_tlb_ppn, pc_if[11:0]} : pc_if;
    wire if_page_fault = mmu_enabled && (!if_tlb_hit || !if_tlb_exec);
    wire if_access_fault = !if_page_fault &&
                           ((if_phys_addr[1:0] != 2'b00) || (if_phys_addr[31:12] != 20'b0));

    wire [31:0] data_phys_addr = mmu_enabled ? {data_tlb_ppn, ex_alu_result[11:0]} : ex_alu_result;
    wire ex_load_page_fault = id_ex_valid && id_ex_is_load &&
                              mmu_enabled && (!data_tlb_hit || !data_tlb_read);
    wire ex_store_page_fault = id_ex_valid && id_ex_is_store &&
                               mmu_enabled && (!data_tlb_hit || !data_tlb_write);

    wire software_irq_pending = software_irq_sync || csr_mip_msip;
    wire timer_irq_pending = timer_irq_sync;
    wire [5:0] plic_source_bits = {keyboard_irq_sync, i2c_irq_sync, spi_irq_sync,
                                   (gpio_irq_sync | external_irq_sync),
                                   uart_irq_sync, 1'b0};
    wire [5:0] plic_active_pending = plic_pending | plic_source_bits;
    wire [5:0] plic_enabled_pending = plic_active_pending & plic_enable;
    wire external_irq_pending = |plic_enabled_pending[5:1];
    wire [2:0] plic_claim_id =
        plic_enabled_pending[1] ? PLIC_ID_UART :
        plic_enabled_pending[2] ? PLIC_ID_GPIO :
        plic_enabled_pending[3] ? PLIC_ID_SPI :
        plic_enabled_pending[4] ? PLIC_ID_I2C :
        plic_enabled_pending[5] ? PLIC_ID_KEYBOARD :
                                  PLIC_ID_NONE;
    wire [5:0] plic_claim_mask =
        (mem_wb_csr_wdata[2:0] == PLIC_ID_UART) ? 6'b000010 :
        (mem_wb_csr_wdata[2:0] == PLIC_ID_GPIO) ? 6'b000100 :
        (mem_wb_csr_wdata[2:0] == PLIC_ID_SPI)  ? 6'b001000 :
        (mem_wb_csr_wdata[2:0] == PLIC_ID_I2C)  ? 6'b010000 :
        (mem_wb_csr_wdata[2:0] == PLIC_ID_KEYBOARD) ? 6'b100000 :
                                                       6'b000000;
    wire software_irq_ready = software_irq_pending && csr_mie[3];
    wire timer_irq_ready = timer_irq_pending && csr_mie[7];
    wire external_irq_ready = external_irq_pending && csr_mie[11];
    wire any_irq_ready = external_irq_ready || software_irq_ready || timer_irq_ready;
    wire [31:0] active_irq_cause = external_irq_ready ? CAUSE_MEI :
                                   software_irq_ready ? CAUSE_MSI :
                                                        CAUSE_MTI;
    wire [31:0] csr_mip_value = {20'b0, external_irq_pending, 3'b0,
                                 timer_irq_pending, 3'b0,
                                 software_irq_pending, 3'b0};
    wire interrupt_enabled = csr_mstatus[3] && any_irq_ready;
    wire pipeline_drained = !if_id_valid && !id_ex_valid && !ex_mem_valid;
    wire irq_can_start = interrupt_enabled && !irq_drain;
    wire irq_take_now = (irq_drain || irq_can_start) && pipeline_drained;
    wire irq_hold_fetch = irq_drain || irq_can_start;
    wire [31:0] mtvec_direct = {csr_mtvec[31:2], 2'b00};
    wire [31:0] csr_mstatus_next = csr_apply_cmd(csr_mstatus, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_mie_next = csr_apply_cmd(csr_mie, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_mtvec_next = csr_apply_cmd(csr_mtvec, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_satp_next = csr_apply_cmd(csr_satp, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_mepc_next = csr_apply_cmd(csr_mepc, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_mcause_next = csr_apply_cmd(csr_mcause, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_mtval_next = csr_apply_cmd(csr_mtval, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_mip_next = csr_apply_cmd(csr_mip_value, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_tlbvpn_next = csr_apply_cmd({12'b0, tlb_vpn[csr_tlbidx]}, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_tlbppn_next = csr_apply_cmd({12'b0, tlb_ppn[csr_tlbidx]}, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_tlbflags_next = csr_apply_cmd({28'b0, tlb_exec[csr_tlbidx],
                                                   tlb_write[csr_tlbidx],
                                                   tlb_read[csr_tlbidx],
                                                   tlb_valid[csr_tlbidx]},
                                                  mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_plic_pending_next = csr_apply_cmd({26'b0, plic_active_pending}, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_plic_enable_next = csr_apply_cmd({26'b0, plic_enable}, mem_wb_csr_wdata, mem_wb_csr_cmd);
    wire [31:0] csr_plic_force_next = csr_apply_cmd(32'b0, mem_wb_csr_wdata, mem_wb_csr_cmd);

    wire data_addr_ram = (data_phys_addr[31:12] == 20'h00000);
    wire data_addr_gpioe = (data_phys_addr == 32'he0000000);
    wire data_addr_gpiof = (data_phys_addr == 32'hf0000000);
    wire data_addr_counter = (data_phys_addr[31:4] == 28'hf000000) && !data_addr_gpiof;
    wire data_addr_ps2 = (data_phys_addr == 32'hd0000000) || (data_phys_addr == 32'hd0000004);
    wire data_addr_valid = data_addr_ram || data_addr_gpioe || data_addr_gpiof || data_addr_counter ||
                           data_addr_ps2;
    wire data_addr_misaligned =
        ((id_ex_dm_ctrl == `dm_word) && (data_phys_addr[1:0] != 2'b00)) ||
        (((id_ex_dm_ctrl == `dm_halfword) || (id_ex_dm_ctrl == `dm_halfword_unsigned)) &&
         (data_phys_addr[0] != 1'b0));
    wire ex_load_access_fault = id_ex_valid && id_ex_is_load &&
                                !ex_load_page_fault && (!data_addr_valid || data_addr_misaligned);
    wire ex_store_access_fault = id_ex_valid && id_ex_is_store &&
                                 !ex_store_page_fault && (!data_addr_valid || data_addr_misaligned);
    wire ex_exception = id_ex_valid &&
                        (id_ex_exception || ex_load_page_fault || ex_store_page_fault ||
                         ex_load_access_fault || ex_store_access_fault);
    wire [31:0] ex_exception_cause =
        id_ex_exception       ? id_ex_exception_cause :
        ex_load_page_fault    ? CAUSE_LOAD_PAGE_FAULT :
        ex_store_page_fault   ? CAUSE_STORE_PAGE_FAULT :
        ex_load_access_fault  ? CAUSE_LOAD_ACCESS_FAULT :
                                CAUSE_STORE_ACCESS_FAULT;
    wire [31:0] ex_exception_tval =
        id_ex_exception ? id_ex_exception_tval :
                          ex_alu_result;

    wire [31:0] ex_result_to_mem =
        (id_ex_is_load || id_ex_is_store) ? data_phys_addr : ex_alu_result;

    assign PC_out = if_phys_addr;
    assign mem_r = ex_mem_valid && ex_mem_memread;
    assign mem_w = ex_mem_valid && ex_mem_memwrite;
    assign Addr_out = ex_mem_alu_result;
    assign Data_out = ex_mem_store_data;
    assign dm_ctrl = ex_mem_dm_ctrl;

    assign wb_data =
        (mem_wb_wdsel == `WDSel_FromMEM) ? mem_wb_mem_data :
        (mem_wb_wdsel == `WDSel_FromPC)  ? mem_wb_pc4 :
        (mem_wb_wdsel == `WDSel_FromCSR) ? mem_wb_csr_rdata :
                                           mem_wb_alu_result;

    function [31:0] csr_read_data;
        input [11:0] addr;
        begin
            case (addr)
                CSR_MSTATUS: csr_read_data = csr_mstatus;
                CSR_MIE:     csr_read_data = csr_mie;
                CSR_MTVEC:   csr_read_data = csr_mtvec;
                CSR_SATP:    csr_read_data = csr_satp;
                CSR_MEPC:    csr_read_data = csr_mepc;
                CSR_MCAUSE:  csr_read_data = csr_mcause;
                CSR_MTVAL:   csr_read_data = csr_mtval;
                CSR_MIP:     csr_read_data = csr_mip_value;
                CSR_TLBIDX:  csr_read_data = {30'b0, csr_tlbidx};
                CSR_TLBVPN:  csr_read_data = {12'b0, tlb_vpn[csr_tlbidx]};
                CSR_TLBPPN:  csr_read_data = {12'b0, tlb_ppn[csr_tlbidx]};
                CSR_TLBFLAGS: csr_read_data = {28'b0, tlb_exec[csr_tlbidx],
                                                tlb_write[csr_tlbidx],
                                                tlb_read[csr_tlbidx],
                                                tlb_valid[csr_tlbidx]};
                CSR_PLIC_PENDING: csr_read_data = {26'b0, plic_active_pending};
                CSR_PLIC_ENABLE:  csr_read_data = {26'b0, plic_enable};
                CSR_PLIC_CLAIM:   csr_read_data = {29'b0, plic_claim_id};
                CSR_PLIC_FORCE:   csr_read_data = 32'b0;
                default:     csr_read_data = 32'b0;
            endcase
        end
    endfunction

    function [31:0] csr_apply_cmd;
        input [31:0] old_value;
        input [31:0] write_value;
        input [1:0]  cmd;
        begin
            case (cmd)
                CSR_CMD_WRITE: csr_apply_cmd = write_value;
                CSR_CMD_SET:   csr_apply_cmd = old_value | write_value;
                CSR_CMD_CLEAR: csr_apply_cmd = old_value & ~write_value;
                default:       csr_apply_cmd = old_value;
            endcase
        end
    endfunction

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
            if_id_inst_trap <= 1'b0;
            if_id_inst_trap_cause <= 32'b0;
            if_id_inst_trap_tval <= 32'b0;

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
            id_ex_is_mret <= 1'b0;
            id_ex_is_load <= 1'b0;
            id_ex_is_store <= 1'b0;
            id_ex_exception <= 1'b0;
            id_ex_exception_cause <= 32'b0;
            id_ex_exception_tval <= 32'b0;
            id_ex_csr_write <= 1'b0;
            id_ex_csr_cmd <= CSR_CMD_WRITE;
            id_ex_csr_addr <= 12'b0;
            id_ex_csr_wdata <= 32'b0;
            id_ex_csr_rdata <= 32'b0;

            ex_mem_valid <= 1'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_pc4 <= 32'b0;
            ex_mem_csr_rdata <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_regwrite <= 1'b0;
            ex_mem_memwrite <= 1'b0;
            ex_mem_memread <= 1'b0;
            ex_mem_wdsel <= `WDSel_FromALU;
            ex_mem_dm_ctrl <= `dm_word;
            ex_mem_csr_write <= 1'b0;
            ex_mem_csr_cmd <= CSR_CMD_WRITE;
            ex_mem_csr_addr <= 12'b0;
            ex_mem_csr_wdata <= 32'b0;

            mem_wb_valid <= 1'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data <= 32'b0;
            mem_wb_pc4 <= 32'b0;
            mem_wb_csr_rdata <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_regwrite <= 1'b0;
            mem_wb_wdsel <= `WDSel_FromALU;
            mem_wb_csr_write <= 1'b0;
            mem_wb_csr_cmd <= CSR_CMD_WRITE;
            mem_wb_csr_addr <= 12'b0;
            mem_wb_csr_wdata <= 32'b0;

            csr_mstatus <= RESET_MSTATUS;
            csr_mie <= RESET_MIE;
            csr_mtvec <= RESET_MTVEC;
            csr_mepc <= 32'b0;
            csr_mcause <= 32'b0;
            csr_mtval <= 32'b0;
            csr_satp <= 32'b0;
            csr_mip_msip <= 1'b0;
            csr_tlbidx <= 2'b0;

            for (tlb_reset_i = 0; tlb_reset_i < 4; tlb_reset_i = tlb_reset_i + 1) begin
                tlb_vpn[tlb_reset_i] <= 20'b0;
                tlb_ppn[tlb_reset_i] <= 20'b0;
            end
            tlb_valid <= 4'b0000;
            tlb_read <= 4'b0000;
            tlb_write <= 4'b0000;
            tlb_exec <= 4'b0000;

            software_irq_meta <= 1'b0;
            software_irq_sync <= 1'b0;
            timer_irq_meta <= 1'b0;
            timer_irq_sync <= 1'b0;
            external_irq_meta <= 1'b0;
            external_irq_sync <= 1'b0;
            uart_irq_meta <= 1'b0;
            uart_irq_sync <= 1'b0;
            gpio_irq_meta <= 1'b0;
            gpio_irq_sync <= 1'b0;
            spi_irq_meta <= 1'b0;
            spi_irq_sync <= 1'b0;
            i2c_irq_meta <= 1'b0;
            i2c_irq_sync <= 1'b0;
            keyboard_irq_meta <= 1'b0;
            keyboard_irq_sync <= 1'b0;
            plic_pending <= 6'b000000;
            plic_enable <= 6'b111110;
            irq_drain <= 1'b0;
            irq_drain_cause <= 32'b0;
        end else begin
            software_irq_meta <= software_irq;
            software_irq_sync <= software_irq_meta;
            timer_irq_meta <= timer_irq;
            timer_irq_sync <= timer_irq_meta;
            external_irq_meta <= external_irq;
            external_irq_sync <= external_irq_meta;
            uart_irq_meta <= uart_irq;
            uart_irq_sync <= uart_irq_meta;
            gpio_irq_meta <= gpio_irq;
            gpio_irq_sync <= gpio_irq_meta;
            spi_irq_meta <= spi_irq;
            spi_irq_sync <= spi_irq_meta;
            i2c_irq_meta <= i2c_irq;
            i2c_irq_sync <= i2c_irq_meta;
            keyboard_irq_meta <= keyboard_irq;
            keyboard_irq_sync <= keyboard_irq_meta;

            if (mem_wb_valid && mem_wb_csr_write && mem_wb_csr_addr == CSR_PLIC_PENDING) begin
                plic_pending <= csr_plic_pending_next[5:0] & 6'b111110;
            end else if (mem_wb_valid && mem_wb_csr_write && mem_wb_csr_addr == CSR_PLIC_CLAIM) begin
                plic_pending <= (plic_pending | plic_source_bits) & ~plic_claim_mask;
            end else if (mem_wb_valid && mem_wb_csr_write && mem_wb_csr_addr == CSR_PLIC_FORCE) begin
                plic_pending <= (plic_pending | plic_source_bits | csr_plic_force_next[5:0]) & 6'b111110;
            end else begin
                plic_pending <= plic_pending | plic_source_bits;
            end

            if (mem_wb_valid && mem_wb_csr_write) begin
                case (mem_wb_csr_addr)
                    CSR_MSTATUS: csr_mstatus <= csr_mstatus_next;
                    CSR_MIE:     csr_mie <= csr_mie_next;
                    CSR_MTVEC:   csr_mtvec <= {csr_mtvec_next[31:2], 2'b00};
                    CSR_SATP:    csr_satp <= {csr_satp_next[31], 31'b0};
                    CSR_MEPC:    csr_mepc <= {csr_mepc_next[31:1], 1'b0};
                    CSR_MCAUSE:  csr_mcause <= csr_mcause_next;
                    CSR_MTVAL:   csr_mtval <= csr_mtval_next;
                    CSR_MIP:     csr_mip_msip <= csr_mip_next[3];
                    CSR_TLBIDX:  csr_tlbidx <= mem_wb_csr_wdata[1:0];
                    CSR_TLBVPN:  tlb_vpn[csr_tlbidx] <= csr_tlbvpn_next[19:0];
                    CSR_TLBPPN:  tlb_ppn[csr_tlbidx] <= csr_tlbppn_next[19:0];
                    CSR_TLBFLAGS: begin
                        tlb_valid[csr_tlbidx] <= csr_tlbflags_next[0];
                        tlb_read[csr_tlbidx] <= csr_tlbflags_next[1];
                        tlb_write[csr_tlbidx] <= csr_tlbflags_next[2];
                        tlb_exec[csr_tlbidx] <= csr_tlbflags_next[3];
                    end
                    CSR_PLIC_ENABLE: plic_enable <= csr_plic_enable_next[5:0] & 6'b111110;
                    default: begin
                    end
                endcase
            end

            if (ex_exception) begin
                csr_mepc <= id_ex_pc;
                csr_mcause <= ex_exception_cause;
                csr_mtval <= ex_exception_tval;
                csr_mstatus[7] <= csr_mstatus[3];
                csr_mstatus[3] <= 1'b0;
                irq_drain <= 1'b0;
            end else if (irq_take_now) begin
                csr_mepc <= pc_if;
                csr_mcause <= irq_drain ? irq_drain_cause : active_irq_cause;
                csr_mtval <= 32'b0;
                csr_mstatus[7] <= csr_mstatus[3];
                csr_mstatus[3] <= 1'b0;
                if ((irq_drain ? irq_drain_cause : active_irq_cause) == CAUSE_MSI) begin
                    csr_mip_msip <= 1'b0;
                end
                irq_drain <= 1'b0;
            end else if (ex_mret) begin
                csr_mstatus[3] <= csr_mstatus[7];
                csr_mstatus[7] <= 1'b1;
            end else if (irq_can_start) begin
                irq_drain <= 1'b1;
                irq_drain_cause <= active_irq_cause;
            end

            mem_wb_valid <= ex_mem_valid;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= Data_in;
            mem_wb_pc4 <= ex_mem_pc4;
            mem_wb_csr_rdata <= ex_mem_csr_rdata;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_regwrite <= ex_mem_regwrite;
            mem_wb_wdsel <= ex_mem_wdsel;
            mem_wb_csr_write <= ex_mem_csr_write;
            mem_wb_csr_cmd <= ex_mem_csr_cmd;
            mem_wb_csr_addr <= ex_mem_csr_addr;
            mem_wb_csr_wdata <= ex_mem_csr_wdata;

            ex_mem_valid <= id_ex_valid && !ex_mret && !ex_exception;
            ex_mem_alu_result <= ex_result_to_mem;
            ex_mem_store_data <= ex_rs2_value;
            ex_mem_pc4 <= id_ex_pc4;
            ex_mem_csr_rdata <= id_ex_csr_rdata;
            ex_mem_rd <= id_ex_rd;
            ex_mem_regwrite <= id_ex_regwrite && !ex_mret && !ex_exception;
            ex_mem_memwrite <= id_ex_memwrite && !ex_mret && !ex_exception;
            ex_mem_memread <= id_ex_is_load && !ex_mret && !ex_exception;
            ex_mem_wdsel <= id_ex_wdsel;
            ex_mem_dm_ctrl <= id_ex_dm_ctrl;
            ex_mem_csr_write <= id_ex_csr_write && !ex_mret && !ex_exception;
            ex_mem_csr_cmd <= id_ex_csr_cmd;
            ex_mem_csr_addr <= id_ex_csr_addr;
            ex_mem_csr_wdata <= id_ex_csr_wdata;

            if (ex_exception) begin
                pc_if <= mtvec_direct;
            end else if (irq_take_now) begin
                pc_if <= mtvec_direct;
            end else if (ex_mret) begin
                pc_if <= csr_mepc;
            end else if (ex_take_branch) begin
                pc_if <= ex_branch_target;
            end else if (irq_hold_fetch) begin
                pc_if <= pc_if;
            end else begin
                pc_if <= pc_if + 32'd4;
            end

            if (ex_exception || irq_take_now || ex_mret || ex_take_branch) begin
                if_id_valid <= 1'b0;
                if_id_pc <= 32'b0;
                if_id_inst <= NOP;
                if_id_inst_trap <= 1'b0;
                if_id_inst_trap_cause <= 32'b0;
                if_id_inst_trap_tval <= 32'b0;

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
                id_ex_is_mret <= 1'b0;
                id_ex_is_load <= 1'b0;
                id_ex_is_store <= 1'b0;
                id_ex_exception <= 1'b0;
                id_ex_exception_cause <= 32'b0;
                id_ex_exception_tval <= 32'b0;
                id_ex_csr_write <= 1'b0;
                id_ex_csr_cmd <= CSR_CMD_WRITE;
                id_ex_csr_addr <= 12'b0;
                id_ex_csr_wdata <= 32'b0;
                id_ex_csr_rdata <= 32'b0;
            end else begin
                if_id_valid <= !irq_hold_fetch;
                if_id_pc <= irq_hold_fetch ? 32'b0 : pc_if;
                if_id_inst <= irq_hold_fetch ? NOP : inst_in;
                if_id_inst_trap <= irq_hold_fetch ? 1'b0 : (if_page_fault || if_access_fault);
                if_id_inst_trap_cause <= if_page_fault ? CAUSE_INST_PAGE_FAULT :
                                         if_access_fault ? CAUSE_INST_ACCESS_FAULT :
                                                           32'b0;
                if_id_inst_trap_tval <= pc_if;

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
                id_ex_is_mret <= if_id_valid && id_is_mret;
                id_ex_is_load <= if_id_valid && id_is_load;
                id_ex_is_store <= if_id_valid && id_is_store;
                id_ex_exception <= id_exception;
                id_ex_exception_cause <= id_exception_cause;
                id_ex_exception_tval <= id_exception_tval;
                id_ex_csr_write <= if_id_valid && id_csr_write;
                id_ex_csr_cmd <= id_csr_cmd;
                id_ex_csr_addr <= id_csr_addr;
                id_ex_csr_wdata <= id_csr_wdata;
                id_ex_csr_rdata <= id_csr_rdata;
            end
        end
    end
endmodule
