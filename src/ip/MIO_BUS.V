`timescale 1ns / 1ps

module MIO_BUS(
    input         clk,
    input         rst,
    input  [4:0]  BTN,
    input  [15:0] SW,
    input  [31:0] PC,
    input         mem_r,
    input         mem_w,
    input  [31:0] Cpu_data2bus,
    input  [31:0] addr_bus,
    input  [31:0] ram_data_out,
    input  [15:0] led_out,
    input  [31:0] counter_out,
    input         counter0_out,
    input         counter1_out,
    input         counter2_out,
    input  [7:0]  ps2_data,
    input         ps2_data_valid,
    input  [3:0]  ps2_data_count,
    input         ps2_fifo_full,
    input         ps2_overflow,
    input         ps2_frame_error,
    input         ps2_parity_error,
    output [31:0] Cpu_data4bus,
    output [31:0] ram_data_in,
    output [9:0]  ram_addr,
    output        data_ram_we,
    output        GPIOf0000000_we,
    output        GPIOe0000000_we,
    output        counter_we,
    output [31:0] Peripheral_in,
    output        ps2_rd_en,
    output        ps2_clear_errors
);
    wire gpioe_addr = (addr_bus == 32'he0000000);
    wire gpiof_addr = (addr_bus == 32'hf0000000);
    wire counter_addr = (addr_bus[31:4] == 28'hf000000) && !gpiof_addr;
    wire ps2_data_addr = (addr_bus == 32'hd0000000);
    wire ps2_status_addr = (addr_bus == 32'hd0000004);
    wire peripheral_addr = gpioe_addr || gpiof_addr || counter_addr ||
                           ps2_data_addr || ps2_status_addr;
    wire [31:0] ps2_status = {20'b0, ps2_data_count, 3'b000, ps2_parity_error,
                              ps2_frame_error, ps2_overflow, ps2_fifo_full,
                              ps2_data_valid};

    assign ram_addr = addr_bus[11:2];
    assign ram_data_in = Cpu_data2bus;
    assign data_ram_we = mem_w && !peripheral_addr;

    assign GPIOe0000000_we = mem_w && gpioe_addr;
    assign GPIOf0000000_we = mem_w && gpiof_addr;
    assign counter_we = mem_w && counter_addr;
    assign Peripheral_in = Cpu_data2bus;
    assign ps2_rd_en = mem_r && ps2_data_addr;
    assign ps2_clear_errors = mem_w && ps2_status_addr;

    assign Cpu_data4bus =
        gpioe_addr ? {11'b0, counter2_out, counter1_out, counter0_out, BTN, SW} :
        gpiof_addr ? {16'b0, led_out} :
        counter_addr ? counter_out :
        ps2_data_addr ? {24'b0, ps2_data} :
        ps2_status_addr ? ps2_status :
        ram_data_out;
endmodule
