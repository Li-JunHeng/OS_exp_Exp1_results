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

## Standalone Check

From a Mac/Linux shell with Icarus Verilog installed:

```sh
make top-syntax
```

This checks the local `src/` tree and the provided stubs without using any parent repository files.
