`timescale 1ns / 1ps

module top(
    input         clk,
    input         rstn,
    input  [15:0] sw_i,
    output [15:0] led_o,
    output [7:0]  disp_an_o,
    output [7:0]  disp_seg_o
);
    wire rst = ~rstn;

    wire [31:0] clkdiv;
    wire        clk_cpu;
    wire [4:0]  btn_clean;
    wire [15:0] sw_clean;

    wire [31:0] inst;
    wire [31:0] pc;
    wire        mem_w;
    wire [31:0] addr_bus;
    wire [31:0] cpu_data_out;
    wire [31:0] cpu_data_in;
    wire [2:0]  dm_ctrl;

    wire [31:0] ram_data_out;
    wire [31:0] bus_data_to_cpu;
    wire [31:0] ram_data_in;
    wire [9:0]  ram_addr;
    wire        data_ram_we;
    wire [31:0] data_write_to_dm;
    wire [3:0]  wea_mem;

    wire        gpio_led_we;
    wire        gpio_display_we;
    wire        counter_we;
    wire [31:0] peripheral_in;
    wire [15:0] led_from_spio;
    wire [15:0] spio_led;
    wire [1:0]  counter_set;
    wire [31:0] counter_out;
    wire        counter0_out;
    wire        counter1_out;
    wire        counter2_out;
    wire        cpu_software_irq;
    wire        cpu_timer_irq;
    wire        cpu_uart_irq;
    wire        cpu_gpio_irq;
    wire        cpu_spi_irq;
    wire        cpu_i2c_irq;

    assign cpu_software_irq = sw_clean[14];
    assign cpu_timer_irq = counter0_out;
    assign cpu_uart_irq = sw_clean[13];
    assign cpu_gpio_irq = sw_clean[15];
    assign cpu_spi_irq = counter1_out;
    assign cpu_i2c_irq = counter2_out;

    Enter U_ENTER(
        .clk(clk),
        .BTN(5'b0),
        .SW(sw_i),
        .BTN_out(btn_clean),
        .SW_out(sw_clean)
    );

    clk_div U_CLK_DIV(
        .clk(clk),
        .rst(rst),
        .SW2(sw_clean[2]),
        .clkdiv(clkdiv),
        .Clk_CPU(clk_cpu)
    );

    seg_display U_SEG_DISPLAY(
        .clk_cpu(clk_cpu),
        .rst(rst),
        .clkdiv(clkdiv),
        .display_sel(sw_clean[7:5]),
        .mem_w(mem_w),
        .gpio_display_we(gpio_display_we),
        .addr_bus(addr_bus),
        .peripheral_in(peripheral_in),
        .spio_led(spio_led),
        .pc(pc),
        .inst(inst),
        .ram_addr(ram_addr),
        .cpu_data_out(cpu_data_out),
        .cpu_data_in(cpu_data_in),
        .led_o(led_o),
        .disp_an_o(disp_an_o),
        .disp_seg_o(disp_seg_o)
    );

    im U_IM(
        .addr(pc[11:2]),
        .dout(inst)
    );

    SCPU U_SCPU(
        .clk(clk_cpu),
        .reset(rst),
        .software_irq(cpu_software_irq),
        .timer_irq(cpu_timer_irq),
        .external_irq(1'b0),
        .uart_irq(cpu_uart_irq),
        .gpio_irq(cpu_gpio_irq),
        .spi_irq(cpu_spi_irq),
        .i2c_irq(cpu_i2c_irq),
        .inst_in(inst),
        .Data_in(cpu_data_in),
        .mem_w(mem_w),
        .PC_out(pc),
        .Addr_out(addr_bus),
        .Data_out(cpu_data_out),
        .dm_ctrl(dm_ctrl),
        .reg_sel(sw_clean[12:8]),
        .reg_data()
    );

    dm_controller U_DM_CONTROLLER(
        .mem_w(mem_w),
        .Addr_in(addr_bus),
        .Data_write(cpu_data_out),
        .dm_ctrl(dm_ctrl),
        .Data_read_from_dm(bus_data_to_cpu),
        .Data_read(cpu_data_in),
        .Data_write_to_dm(data_write_to_dm),
        .wea_mem(wea_mem)
    );

    MIO_BUS U_MIO_BUS(
        .clk(clk),
        .rst(rst),
        .BTN(btn_clean),
        .SW(sw_clean),
        .PC(pc),
        .mem_w(mem_w),
        .Cpu_data2bus(data_write_to_dm),
        .addr_bus(addr_bus),
        .ram_data_out(ram_data_out),
        .led_out(led_from_spio),
        .counter_out(counter_out),
        .counter0_out(counter0_out),
        .counter1_out(counter1_out),
        .counter2_out(counter2_out),
        .Cpu_data4bus(bus_data_to_cpu),
        .ram_data_in(ram_data_in),
        .ram_addr(ram_addr),
        .data_ram_we(data_ram_we),
        .GPIOf0000000_we(gpio_led_we),
        .GPIOe0000000_we(gpio_display_we),
        .counter_we(counter_we),
        .Peripheral_in(peripheral_in)
    );

    data_ram U_DATA_RAM(
        .clk(clk_cpu),
        .we(data_ram_we ? wea_mem : 4'b0000),
        .addr(ram_addr),
        .din(ram_data_in),
        .dout(ram_data_out)
    );

    SPIO U_SPIO(
        .clk(clk_cpu),
        .rst(rst),
        .EN(gpio_led_we),
        .P_Data(peripheral_in),
        .counter_set(counter_set),
        .LED_out(led_from_spio),
        .led(spio_led),
        .GPIOf0()
    );

    Counter_x U_COUNTER(
        .clk(clk),
        .rst(rst),
        .clk0(clkdiv[6]),
        .clk1(clkdiv[9]),
        .clk2(clkdiv[11]),
        .counter_we(counter_we),
        .counter_val(peripheral_in),
        .counter_ch(counter_set),
        .counter0_OUT(counter0_out),
        .counter1_OUT(counter1_out),
        .counter2_OUT(counter2_out),
        .counter_out(counter_out)
    );

endmodule
