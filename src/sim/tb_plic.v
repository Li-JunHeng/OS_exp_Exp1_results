`timescale 1ns / 1ps

module tb_plic;
    localparam [31:0] NOP = 32'h0000_0013;
    localparam [31:0] CAUSE_MEI = 32'h8000_000b;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg uart_irq = 1'b0;
    reg gpio_irq = 1'b0;
    reg spi_irq = 1'b0;
    reg i2c_irq = 1'b0;
    reg keyboard_irq = 1'b0;
    reg [4:0] reg_sel = 5'd10;

    wire mem_w;
    wire [31:0] pc;
    wire [31:0] addr_out;
    wire [31:0] data_out;
    wire [2:0] dm_ctrl;
    wire [31:0] reg_data;

    reg [31:0] imem [0:255];
    wire [31:0] inst = imem[pc[9:2]];

    integer i;

    SCPU U_SCPU(
        .clk(clk),
        .reset(reset),
        .software_irq(1'b0),
        .timer_irq(1'b0),
        .external_irq(1'b0),
        .uart_irq(uart_irq),
        .gpio_irq(gpio_irq),
        .spi_irq(spi_irq),
        .i2c_irq(i2c_irq),
        .keyboard_irq(keyboard_irq),
        .inst_in(inst),
        .Data_in(32'b0),
        .mem_r(),
        .mem_w(mem_w),
        .PC_out(pc),
        .Addr_out(addr_out),
        .Data_out(data_out),
        .dm_ctrl(dm_ctrl),
        .reg_sel(reg_sel),
        .reg_data(reg_data)
    );

    always #5 clk = ~clk;

    task load_program;
        begin
            for (i = 0; i < 256; i = i + 1) begin
                imem[i] = NOP;
            end
            imem[10'h020] = 32'h7d20_1573; // 0x80: csrrw x10, plicclaim, x0
            imem[10'h021] = NOP;
            imem[10'h022] = NOP;
            imem[10'h023] = NOP;
            imem[10'h024] = 32'h7d25_1073; // csrrw x0, plicclaim, x10
            imem[10'h025] = NOP;
            imem[10'h026] = NOP;
            imem[10'h027] = 32'h3020_0073; // mret
        end
    endtask

    task reset_cpu;
        begin
            uart_irq = 1'b0;
            gpio_irq = 1'b0;
            spi_irq = 1'b0;
            i2c_irq = 1'b0;
            keyboard_irq = 1'b0;
            reset = 1'b1;
            repeat (4) @(posedge clk);
            reset = 1'b0;
            @(posedge clk);
        end
    endtask

    task pulse_irq;
        input [2:0] irq_id;
        begin
            case (irq_id)
                3'd1: uart_irq = 1'b1;
                3'd2: gpio_irq = 1'b1;
                3'd3: spi_irq = 1'b1;
                3'd4: i2c_irq = 1'b1;
                3'd5: keyboard_irq = 1'b1;
                default: begin
                end
            endcase
            repeat (3) @(posedge clk);
            uart_irq = 1'b0;
            gpio_irq = 1'b0;
            spi_irq = 1'b0;
            i2c_irq = 1'b0;
            keyboard_irq = 1'b0;
        end
    endtask

    task check_irq;
        input [2:0] irq_id;
        integer cycle;
        reg saw_trap;
        reg saw_claim;
        begin
            load_program();
            reset_cpu();
            pulse_irq(irq_id);

            saw_trap = 1'b0;
            saw_claim = 1'b0;
            begin : wait_loop
                for (cycle = 0; cycle < 160; cycle = cycle + 1) begin
                    @(posedge clk);
                    if (pc == 32'h0000_0080 && U_SCPU.csr_mcause == CAUSE_MEI) begin
                        saw_trap = 1'b1;
                    end
                    if (reg_data == {29'b0, irq_id}) begin
                        saw_claim = 1'b1;
                    end
                    if (saw_trap && saw_claim && pc < 32'h0000_0080 &&
                        ((U_SCPU.plic_pending & (6'b000001 << irq_id)) == 6'b0)) begin
                        disable wait_loop;
                    end
                end
            end

            if (!saw_trap) begin
                $fatal(1, "PLIC irq %0d did not enter MEI trap, mcause=%h pc=%h",
                       irq_id, U_SCPU.csr_mcause, pc);
            end
            if (!saw_claim || reg_data != {29'b0, irq_id}) begin
                $fatal(1, "PLIC irq %0d claim mismatch, x10=%h claim=%h pending=%b",
                       irq_id, reg_data, U_SCPU.plic_claim_id, U_SCPU.plic_pending);
            end
            if ((U_SCPU.plic_pending & (6'b000001 << irq_id)) != 6'b0) begin
                $fatal(1, "PLIC irq %0d was not completed, pending=%b",
                       irq_id, U_SCPU.plic_pending);
            end
        end
    endtask

    initial begin
        check_irq(3'd1);
        check_irq(3'd2);
        check_irq(3'd3);
        check_irq(3'd4);
        check_irq(3'd5);
        $display("PASS: UART/GPIO/SPI/I2C/keyboard PLIC interrupt IDs were claimed and completed");
        $finish;
    end
endmodule
