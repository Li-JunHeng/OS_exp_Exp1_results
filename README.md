# Exp1 Results and Board Bring-Up

This repository is self-contained for board bring-up. It is also mounted as the parent CPU project's `results/` submodule, but it does not require the parent repository to configure Vivado, build a bitstream, or program the board.

## Quick Board Flow

Run these from this directory on a machine with Vivado installed and available in `PATH`.

```bat
00_setup_project.bat
01_build_bitstream.bat
02_program_board.bat
```

Equivalent Vivado Tcl console commands:

```tcl
source scripts/setup_project.tcl
source scripts/build_bitstream.tcl
source scripts/program_board.tcl
```

`01_build_bitstream.bat` writes the final bitstream to:

```text
bitstream/OS_Exp_1_top.bit
```

`02_program_board.bat` downloads that bitstream to the first detected `xc7a100t*` device.

## GUI Flow

If you prefer Vivado GUI:

1. Run `00_setup_project.bat` once.
2. Run `03_open_gui.bat`.
3. In Vivado, confirm top is `top`.
4. Run synthesis, implementation, and generate bitstream.
5. Open Hardware Manager and program the board with `bitstream/OS_Exp_1_top.bit` or `OS_Exp_1.runs/impl_1/top.bit`.

## Important Notes

- The scripts add sources from this repository's local `src/` and `constraints/` directories; a parent repository checkout is not needed.
- `scripts/setup_project.tcl` intentionally excludes the provided CPU black-box stub (`SCPU.v`/`SCPU.edf`) because it conflicts with the implemented `src/cpu/SCPU.v`.
- `memory/testac.dat` and `memory/D_mem.dat` are copied into the synthesis run directory so Vivado can resolve `$readmemh("memory/...")`.
- Generated `.bit`, `.rpt`, `.jou`, and `.log` files are ignored by default. Commit them only if the submission explicitly requires generated artifacts.

## VGA Rogue-lite Demo

- The board top now exposes the physical Nexys A7 VGA connector as `vga_red[3:0]`, `vga_green[3:0]`, `vga_blue[3:0]`, `vga_hsync`, and `vga_vsync`. The design outputs 640x480 timing and lets an external 1080p monitor scale it.
- The CPU runs directly from the 100 MHz board clock (`clk_cpu = clk`). Post-route timing for the generated bitstream met the 100 MHz constraint with WNS 0.482 ns.
- `src/board/vga_tile_sprite_display.v` provides a 320x240 logical Tile+Sprite renderer scaled 2x to VGA. VGA MMIO lives at `0xc0000000`: control/status, 20x15 tilemap, 32 sprites, and 16 palette entries.
- `firmware/build.ps1` builds the game firmware through `C -> asm -> ELF -> DAT`, using `riscv64-unknown-elf-gcc` from PATH or the PlatformIO fallback toolchain. It writes `memory/testac.dat` and `memory/D_mem.dat`.
- The game firmware uses PS/2 keyboard interrupts through the existing PLIC keyboard source (`id=5`) and VBlank as the machine timer interrupt source.

## CPU Interrupt Support

- `SCPU` has separate machine software, timer, generic external, UART, GPIO, SPI, I2C, and PS/2 keyboard interrupt inputs. The board top maps software interrupt to switch 14, timer interrupt to counter channel 0, UART to switch 13, GPIO to switch 15, SPI to counter channel 1, I2C to counter channel 2, and keyboard interrupt to the PS/2 receiver FIFO-not-empty signal.
- The default machine trap vector is `mtvec = 0x00000080`. Traps save the return PC in `mepc`, write `mcause` and `mtval`, clear `mstatus.MIE`, and fetch from `mtvec`; `mret` restores `mstatus.MIE` and jumps back to `mepc`.
- Implemented machine interrupts: software interrupt `mcause = 0x80000003`, timer interrupt `mcause = 0x80000007`, and external interrupt `mcause = 0x8000000b`.
- Implemented synchronous traps: instruction access fault, illegal instruction, breakpoint (`ebreak`), machine environment call (`ecall`), load access fault, store access fault, instruction page fault, load page fault, and store page fault.
- Implemented CSR instructions are `csrrw/csrrs/csrrc` and their immediate forms for `mstatus`, `mie`, `mtvec`, `mepc`, `mcause`, `mtval`, `mip`, `satp`, and the custom TLB CSRs.
- The simplified MMU is enabled by `satp[31]` and uses 4KB pages with a 4-entry fully-associative TLB. Custom CSRs `0x7c0..0x7c3` select and program `tlbidx`, `tlbvpn`, `tlbppn`, and `tlbflags`; flag bits are `V/R/W/X` in bits `0..3`.
- A simplified PLIC is implemented for concrete external interrupt IDs: UART=1, GPIO=2, SPI=3, I2C=4, and keyboard=5. Custom CSRs `0x7d0..0x7d3` expose `plicpending`, `plicenable`, `plicclaim`, and `plicforce`; `plicclaim` returns the active ID, and writing the handled ID back completes the interrupt.
- The PS/2 keyboard controller is memory-mapped at `0xd0000000` and `0xd0000004`. Reading `0xd0000000` returns the next raw scan-code byte in bits `7..0` and pops the FIFO. Reading `0xd0000004` returns status: bit 0 `valid`, bit 1 `full`, bit 2 `overflow`, bit 3 `frame_error`, bit 4 `parity_error`, and bits `11..8` FIFO count. Writing `0xd0000004` clears sticky error flags. The hardware validates PS/2 start/stop/parity bits, times out partial frames, and buffers up to 8 scan-code bytes.

## Standalone Check

From a Mac/Linux shell with Icarus Verilog installed:

```sh
make top-syntax
```

This checks the local `src/` tree and the provided stubs without using any parent repository files.
