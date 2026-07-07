.PHONY: top-syntax clean

top-syntax:
	mkdir -p build/sim
	iverilog -g2012 -Wall -I src/cpu -o build/sim/top_syntax.vvp \
		src/board/top.v src/board/data_ram.v \
		src/cpu/SCPU.v src/cpu/ctrl.v src/cpu/alu.v src/cpu/PC.v \
		src/cpu/NPC.v src/cpu/EXT.v src/cpu/RF.v src/cpu/im.v \
		src/io/Enter.v src/io/clk_div.v src/io/Counter_3_IO.v \
		src/ip/MIO_BUS.V src/ip/Multi_8CH32.v src/ip/SPIO.v \
		src/ip/SSeg7.v src/ip/dm_controller.v

clean:
	rm -rf build
