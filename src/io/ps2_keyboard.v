`timescale 1ns / 1ps

module ps2_keyboard(
    input        wr_clk,
    input        rd_clk,
    input        rst,
    input        ps2_clk,
    input        ps2_data,
    input        rd_en,
    input        clear_errors,
    output [7:0] data,
    output [7:0] latest_data,
    output       data_valid,
    output       irq,
    output [3:0] data_count,
    output       fifo_full,
    output       overflow,
    output       frame_error,
    output       parity_error
);
    localparam FIFO_ADDR_BITS = 3;
    localparam FIFO_DEPTH = 8;
    localparam [3:0] FIFO_FULL_COUNT = 4'd8;
    localparam [17:0] FRAME_TIMEOUT = 18'd250000;

    reg [7:0] fifo_mem [0:FIFO_DEPTH-1];

    reg [FIFO_ADDR_BITS:0] wr_bin;
    reg [FIFO_ADDR_BITS:0] wr_gray;
    reg [FIFO_ADDR_BITS:0] rd_bin;
    reg [FIFO_ADDR_BITS:0] rd_gray;

    reg [FIFO_ADDR_BITS:0] rd_gray_wr_meta;
    reg [FIFO_ADDR_BITS:0] rd_gray_wr_sync;
    reg [FIFO_ADDR_BITS:0] wr_gray_rd_meta;
    reg [FIFO_ADDR_BITS:0] wr_gray_rd_sync;

    reg [2:0] ps2_clk_sync;
    reg [2:0] ps2_data_sync;
    reg [3:0] bit_count;
    reg [7:0] frame_byte;
    reg       frame_parity;
    reg       frame_bad;
    reg [17:0] timeout_cnt;
    reg [7:0]  latest_data_wr;
    reg        latest_toggle_wr;
    reg [7:0]  latest_data_rd;
    reg        latest_toggle_rd_meta;
    reg        latest_toggle_rd_sync;
    reg        latest_toggle_rd_last;

    reg overflow_wr;
    reg frame_error_wr;
    reg parity_error_wr;
    reg clear_toggle_rd;
    reg clear_toggle_wr_meta;
    reg clear_toggle_wr_sync;
    reg clear_toggle_wr_last;

    reg overflow_rd_meta;
    reg overflow_rd_sync;
    reg frame_error_rd_meta;
    reg frame_error_rd_sync;
    reg parity_error_rd_meta;
    reg parity_error_rd_sync;

    wire ps2_falling_edge = (ps2_clk_sync[2:1] == 2'b10);
    wire ps2_sample = ps2_data_sync[2];

    wire [FIFO_ADDR_BITS:0] wr_bin_next = wr_bin + 1'b1;
    wire [FIFO_ADDR_BITS:0] wr_gray_next = bin_to_gray(wr_bin_next);
    wire fifo_full_wr = (wr_gray == {~rd_gray_wr_sync[FIFO_ADDR_BITS:FIFO_ADDR_BITS-1],
                                     rd_gray_wr_sync[FIFO_ADDR_BITS-2:0]});

    wire [FIFO_ADDR_BITS:0] rd_bin_next = rd_bin + 1'b1;
    wire [FIFO_ADDR_BITS:0] rd_gray_next = bin_to_gray(rd_bin_next);
    wire fifo_empty_rd = (rd_gray == wr_gray_rd_sync);
    wire [FIFO_ADDR_BITS:0] wr_bin_rd = gray_to_bin(wr_gray_rd_sync);
    wire fifo_push = ps2_falling_edge && (bit_count == 4'd10) &&
                     !frame_bad && ps2_sample && ((^frame_byte) ^ frame_parity) &&
                     !fifo_full_wr;

    assign data = fifo_mem[rd_bin[FIFO_ADDR_BITS-1:0]];
    assign latest_data = latest_data_rd;
    assign data_valid = !fifo_empty_rd;
    assign irq = data_valid;
    assign data_count = wr_bin_rd - rd_bin;
    assign fifo_full = (data_count == FIFO_FULL_COUNT);
    assign overflow = overflow_rd_sync;
    assign frame_error = frame_error_rd_sync;
    assign parity_error = parity_error_rd_sync;

    function [FIFO_ADDR_BITS:0] bin_to_gray;
        input [FIFO_ADDR_BITS:0] bin;
        begin
            bin_to_gray = (bin >> 1) ^ bin;
        end
    endfunction

    function [FIFO_ADDR_BITS:0] gray_to_bin;
        input [FIFO_ADDR_BITS:0] gray;
        integer i;
        begin
            gray_to_bin[FIFO_ADDR_BITS] = gray[FIFO_ADDR_BITS];
            for (i = FIFO_ADDR_BITS - 1; i >= 0; i = i - 1) begin
                gray_to_bin[i] = gray_to_bin[i + 1] ^ gray[i];
            end
        end
    endfunction

    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin
            wr_bin <= 0;
            wr_gray <= 0;
            rd_gray_wr_meta <= 0;
            rd_gray_wr_sync <= 0;
            ps2_clk_sync <= 3'b111;
            ps2_data_sync <= 3'b111;
            bit_count <= 4'b0;
            frame_byte <= 8'b0;
            frame_parity <= 1'b0;
            frame_bad <= 1'b0;
            timeout_cnt <= 18'b0;
            latest_data_wr <= 8'b0;
            latest_toggle_wr <= 1'b0;
            overflow_wr <= 1'b0;
            frame_error_wr <= 1'b0;
            parity_error_wr <= 1'b0;
            clear_toggle_wr_meta <= 1'b0;
            clear_toggle_wr_sync <= 1'b0;
            clear_toggle_wr_last <= 1'b0;
        end else begin
            rd_gray_wr_meta <= rd_gray;
            rd_gray_wr_sync <= rd_gray_wr_meta;
            clear_toggle_wr_meta <= clear_toggle_rd;
            clear_toggle_wr_sync <= clear_toggle_wr_meta;
            clear_toggle_wr_last <= clear_toggle_wr_sync;

            if (clear_toggle_wr_sync != clear_toggle_wr_last) begin
                overflow_wr <= 1'b0;
                frame_error_wr <= 1'b0;
                parity_error_wr <= 1'b0;
            end

            ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
            ps2_data_sync <= {ps2_data_sync[1:0], ps2_data};

            if (bit_count != 4'b0) begin
                if (ps2_falling_edge) begin
                    timeout_cnt <= 18'b0;
                end else if (timeout_cnt == FRAME_TIMEOUT) begin
                    bit_count <= 4'b0;
                    timeout_cnt <= 18'b0;
                    frame_error_wr <= 1'b1;
                end else begin
                    timeout_cnt <= timeout_cnt + 1'b1;
                end
            end

            if (ps2_falling_edge) begin
                case (bit_count)
                    4'd0: begin
                        frame_byte <= 8'b0;
                        frame_parity <= 1'b0;
                        frame_bad <= ps2_sample;
                        bit_count <= 4'd1;
                        timeout_cnt <= 18'b0;
                    end
                    4'd1, 4'd2, 4'd3, 4'd4,
                    4'd5, 4'd6, 4'd7, 4'd8: begin
                        frame_byte[bit_count - 1'b1] <= ps2_sample;
                        bit_count <= bit_count + 1'b1;
                    end
                    4'd9: begin
                        frame_parity <= ps2_sample;
                        bit_count <= 4'd10;
                    end
                    4'd10: begin
                        bit_count <= 4'b0;
                        if (frame_bad || !ps2_sample) begin
                            frame_error_wr <= 1'b1;
                        end else if (!((^frame_byte) ^ frame_parity)) begin
                            parity_error_wr <= 1'b1;
                        end else begin
                            latest_data_wr <= frame_byte;
                            latest_toggle_wr <= ~latest_toggle_wr;
                            if (fifo_full_wr) begin
                                overflow_wr <= 1'b1;
                            end else begin
                                wr_bin <= wr_bin_next;
                                wr_gray <= wr_gray_next;
                            end
                        end
                    end
                    default: begin
                        bit_count <= 4'b0;
                        frame_error_wr <= 1'b1;
                    end
                endcase
            end
        end
    end

    always @(posedge wr_clk) begin
        if (fifo_push) begin
            fifo_mem[wr_bin[FIFO_ADDR_BITS-1:0]] <= frame_byte;
        end
    end

    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin
            rd_bin <= 0;
            rd_gray <= 0;
            wr_gray_rd_meta <= 0;
            wr_gray_rd_sync <= 0;
            clear_toggle_rd <= 1'b0;
            latest_data_rd <= 8'b0;
            latest_toggle_rd_meta <= 1'b0;
            latest_toggle_rd_sync <= 1'b0;
            latest_toggle_rd_last <= 1'b0;
            overflow_rd_meta <= 1'b0;
            overflow_rd_sync <= 1'b0;
            frame_error_rd_meta <= 1'b0;
            frame_error_rd_sync <= 1'b0;
            parity_error_rd_meta <= 1'b0;
            parity_error_rd_sync <= 1'b0;
        end else begin
            wr_gray_rd_meta <= wr_gray;
            wr_gray_rd_sync <= wr_gray_rd_meta;
            latest_toggle_rd_meta <= latest_toggle_wr;
            latest_toggle_rd_sync <= latest_toggle_rd_meta;
            latest_toggle_rd_last <= latest_toggle_rd_sync;

            if (latest_toggle_rd_sync != latest_toggle_rd_last) begin
                latest_data_rd <= latest_data_wr;
            end

            overflow_rd_meta <= overflow_wr;
            overflow_rd_sync <= overflow_rd_meta;
            frame_error_rd_meta <= frame_error_wr;
            frame_error_rd_sync <= frame_error_rd_meta;
            parity_error_rd_meta <= parity_error_wr;
            parity_error_rd_sync <= parity_error_rd_meta;

            if (clear_errors) begin
                clear_toggle_rd <= ~clear_toggle_rd;
            end

            if (rd_en && !fifo_empty_rd) begin
                rd_bin <= rd_bin_next;
                rd_gray <= rd_gray_next;
            end
        end
    end
endmodule
