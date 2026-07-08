`timescale 1ns / 1ps

module tb_ps2_keyboard;
    reg wr_clk = 1'b0;
    reg rd_clk = 1'b0;
    reg rst = 1'b1;
    reg ps2_clk = 1'b1;
    reg ps2_data = 1'b1;
    reg rd_en = 1'b0;
    reg clear_errors = 1'b0;

    wire [7:0] data;
    wire [7:0] latest_data;
    wire data_valid;
    wire irq;
    wire [3:0] data_count;
    wire fifo_full;
    wire overflow;
    wire frame_error;
    wire parity_error;

    integer cycle;

    ps2_keyboard U_PS2_KEYBOARD(
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .rd_en(rd_en),
        .clear_errors(clear_errors),
        .data(data),
        .latest_data(latest_data),
        .data_valid(data_valid),
        .irq(irq),
        .data_count(data_count),
        .fifo_full(fifo_full),
        .overflow(overflow),
        .frame_error(frame_error),
        .parity_error(parity_error)
    );

    always #5 wr_clk = ~wr_clk;
    always #13 rd_clk = ~rd_clk;

    task ps2_bit;
        input bit_value;
        begin
            ps2_data = bit_value;
            repeat (20) @(posedge wr_clk);
            ps2_clk = 1'b0;
            repeat (20) @(posedge wr_clk);
            ps2_clk = 1'b1;
            repeat (20) @(posedge wr_clk);
        end
    endtask

    task ps2_byte;
        input [7:0] code;
        input       invert_parity;
        integer i;
        reg parity_bit;
        begin
            parity_bit = ~(^code);
            if (invert_parity) begin
                parity_bit = ~parity_bit;
            end

            ps2_bit(1'b0);
            for (i = 0; i < 8; i = i + 1) begin
                ps2_bit(code[i]);
            end
            ps2_bit(parity_bit);
            ps2_bit(1'b1);
            ps2_data = 1'b1;
            repeat (50) @(posedge wr_clk);
        end
    endtask

    task wait_valid;
        begin
            for (cycle = 0; cycle < 200; cycle = cycle + 1) begin
                @(posedge rd_clk);
                if (data_valid) begin
                    disable wait_valid;
                end
            end
            $fatal(1, "PS/2 byte did not reach FIFO");
        end
    endtask

    initial begin
        repeat (10) @(posedge wr_clk);
        rst = 1'b0;
        repeat (5) @(posedge rd_clk);

        ps2_byte(8'h1c, 1'b0);
        wait_valid();

        if (!irq || data_count != 4'd1 || data != 8'h1c || latest_data != 8'h1c) begin
            $fatal(1, "PS/2 valid byte mismatch: irq=%b count=%0d data=%h latest=%h",
                   irq, data_count, data, latest_data);
        end

        ps2_byte(8'h32, 1'b0);
        repeat (20) @(posedge rd_clk);
        if (data_count != 4'd2 || data != 8'h1c || latest_data != 8'h32) begin
            $fatal(1, "PS/2 latest code should update without popping FIFO: count=%0d data=%h latest=%h",
                   data_count, data, latest_data);
        end

        @(posedge rd_clk);
        rd_en = 1'b1;
        @(posedge rd_clk);
        rd_en = 1'b0;
        repeat (4) @(posedge rd_clk);
        if (!data_valid || data_count != 4'd1 || data != 8'h32) begin
            $fatal(1, "PS/2 FIFO first pop mismatch: valid=%b count=%0d data=%h",
                   data_valid, data_count, data);
        end

        @(posedge rd_clk);
        rd_en = 1'b1;
        @(posedge rd_clk);
        rd_en = 1'b0;
        repeat (4) @(posedge rd_clk);
        if (data_valid) begin
            $fatal(1, "PS/2 FIFO did not empty after second pop");
        end

        ps2_byte(8'h1c, 1'b1);
        repeat (20) @(posedge rd_clk);
        if (!parity_error || data_valid) begin
            $fatal(1, "PS/2 parity error was not reported cleanly: parity=%b valid=%b",
                   parity_error, data_valid);
        end

        @(posedge rd_clk);
        clear_errors = 1'b1;
        @(posedge rd_clk);
        clear_errors = 1'b0;
        repeat (8) @(posedge rd_clk);
        if (parity_error || frame_error || overflow) begin
            $fatal(1, "PS/2 error flags did not clear");
        end

        ps2_byte(8'h11, 1'b0);
        ps2_byte(8'h22, 1'b0);
        ps2_byte(8'h33, 1'b0);
        ps2_byte(8'h44, 1'b0);
        ps2_byte(8'h55, 1'b0);
        ps2_byte(8'h66, 1'b0);
        ps2_byte(8'h77, 1'b0);
        ps2_byte(8'h88, 1'b0);
        ps2_byte(8'h99, 1'b0);
        repeat (40) @(posedge rd_clk);
        if (!overflow || data_count != 4'd8 || data != 8'h11 || latest_data != 8'h99) begin
            $fatal(1, "PS/2 FIFO full behavior mismatch: overflow=%b count=%0d data=%h latest=%h",
                   overflow, data_count, data, latest_data);
        end

        $display("PASS: PS/2 keyboard receiver accepted scan codes, tracked latest data, raised IRQ, and handled errors");
        $finish;
    end
endmodule
