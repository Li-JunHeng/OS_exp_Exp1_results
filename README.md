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

## CPU Interrupt Support

- `SCPU` has separate machine software, timer, generic external, UART, GPIO, SPI, and I2C interrupt inputs. The board top maps software interrupt to switch 14, timer interrupt to counter channel 0, UART to switch 13, GPIO to switch 15, SPI to counter channel 1, and I2C to counter channel 2.
- The default machine trap vector is `mtvec = 0x00000080`. Traps save the return PC in `mepc`, write `mcause` and `mtval`, clear `mstatus.MIE`, and fetch from `mtvec`; `mret` restores `mstatus.MIE` and jumps back to `mepc`.
- Implemented machine interrupts: software interrupt `mcause = 0x80000003`, timer interrupt `mcause = 0x80000007`, and external interrupt `mcause = 0x8000000b`.
- Implemented synchronous traps: instruction access fault, illegal instruction, breakpoint (`ebreak`), machine environment call (`ecall`), load access fault, store access fault, instruction page fault, load page fault, and store page fault.
- Implemented CSR instructions are `csrrw/csrrs/csrrc` and their immediate forms for `mstatus`, `mie`, `mtvec`, `mepc`, `mcause`, `mtval`, `mip`, `satp`, and the custom TLB CSRs.
- The simplified MMU is enabled by `satp[31]` and uses 4KB pages with a 4-entry fully-associative TLB. Custom CSRs `0x7c0..0x7c3` select and program `tlbidx`, `tlbvpn`, `tlbppn`, and `tlbflags`; flag bits are `V/R/W/X` in bits `0..3`.
- A simplified PLIC is implemented for concrete external interrupt IDs: UART=1, GPIO=2, SPI=3, and I2C=4. Custom CSRs `0x7d0..0x7d3` expose `plicpending`, `plicenable`, `plicclaim`, and `plicforce`; `plicclaim` returns the active ID, and writing the handled ID back completes the interrupt.

## Standalone Check

From a Mac/Linux shell with Icarus Verilog installed:

```sh
make top-syntax
```

This checks the local `src/` tree and the provided stubs without using any parent repository files.
