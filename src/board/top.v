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

    reg  [31:0] display_value;
    reg  [31:0] selected_display_value;
    reg  [7:0]  disp_an_mux;
    reg  [7:0]  disp_seg_mux;
    reg  [15:0] led_mux;
    reg  [2:0]  scan_digit;
    reg  [3:0]  selected_nibble;
    reg  [7:0]  raw_seg;
    reg  [7:0]  hex_seg;

    wire display_we = mem_w && (addr_bus == 32'he0000000);

    assign led_o = led_mux;
    assign disp_an_o = disp_an_mux;
    assign disp_seg_o = disp_seg_mux;

    always @(posedge clk_cpu or posedge rst) begin
        if (rst)
            display_value <= 32'hffff_ffff;
        else if (display_we || gpio_display_we)
            display_value <= peripheral_in;
    end

    always @(*) begin
        case (sw_clean[7:5])
            3'b000: led_mux = spio_led;
            3'b001: led_mux = pc[17:2];
            3'b010: led_mux = inst[15:0];
            3'b011: led_mux = {13'b0, gpio_display_we, mem_w, display_we};
            3'b100: led_mux = {6'b0, ram_addr};
            3'b101: led_mux = cpu_data_out[15:0];
            3'b110: led_mux = cpu_data_in[15:0];
            default: led_mux = addr_bus[15:0];
        endcase
    end

    always @(*) begin
        case (sw_clean[7:5])
            3'b000: selected_display_value = display_value;
            3'b001: selected_display_value = pc;
            3'b010: selected_display_value = inst;
            3'b011: selected_display_value = display_value;
            3'b100: selected_display_value = {22'b0, ram_addr};
            3'b101: selected_display_value = cpu_data_out;
            3'b110: selected_display_value = cpu_data_in;
            default: selected_display_value = addr_bus;
        endcase
    end

    always @(*) begin
        case (selected_nibble)
            4'h0: hex_seg = 8'b1100_0000;
            4'h1: hex_seg = 8'b1111_1001;
            4'h2: hex_seg = 8'b1010_0100;
            4'h3: hex_seg = 8'b1011_0000;
            4'h4: hex_seg = 8'b1001_1001;
            4'h5: hex_seg = 8'b1001_0010;
            4'h6: hex_seg = 8'b1000_0010;
            4'h7: hex_seg = 8'b1111_1000;
            4'h8: hex_seg = 8'b1000_0000;
            4'h9: hex_seg = 8'b1001_0000;
            4'ha: hex_seg = 8'b1000_1000;
            4'hb: hex_seg = 8'b1000_0011;
            4'hc: hex_seg = 8'b1100_0110;
            4'hd: hex_seg = 8'b1010_0001;
            4'he: hex_seg = 8'b1000_0110;
            default: hex_seg = 8'b1000_1110;
        endcase
    end

    always @(*) begin
        case (scan_digit[1:0])
            2'd0: raw_seg = display_value[7:0];
            2'd1: raw_seg = display_value[15:8];
            2'd2: raw_seg = display_value[23:16];
            default: raw_seg = display_value[31:24];
        endcase
    end

    always @(*) begin
        case (clkdiv[15:13])
            3'd0: begin scan_digit = 3'd0; disp_an_mux = 8'b1111_1110; selected_nibble = selected_display_value[3:0]; end
            3'd1: begin scan_digit = 3'd1; disp_an_mux = 8'b1111_1101; selected_nibble = selected_display_value[7:4]; end
            3'd2: begin scan_digit = 3'd2; disp_an_mux = 8'b1111_1011; selected_nibble = selected_display_value[11:8]; end
            3'd3: begin scan_digit = 3'd3; disp_an_mux = 8'b1111_0111; selected_nibble = selected_display_value[15:12]; end
            3'd4: begin scan_digit = 3'd4; disp_an_mux = 8'b1110_1111; selected_nibble = selected_display_value[19:16]; end
            3'd5: begin scan_digit = 3'd5; disp_an_mux = 8'b1101_1111; selected_nibble = selected_display_value[23:20]; end
            3'd6: begin scan_digit = 3'd6; disp_an_mux = 8'b1011_1111; selected_nibble = selected_display_value[27:24]; end
            default: begin scan_digit = 3'd7; disp_an_mux = 8'b0111_1111; selected_nibble = selected_display_value[31:28]; end
        endcase
        disp_seg_mux = (sw_clean[7:5] == 3'b000) ? raw_seg : hex_seg;
    end

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

    im U_IM(
        .addr(pc[11:2]),
        .dout(inst)
    );

    SCPU U_SCPU(
        .clk(clk_cpu),
        .reset(rst),
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
