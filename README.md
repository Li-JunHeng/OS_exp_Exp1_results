# Exp1 Results and Board Bring-Up

This directory is a Git submodule mounted at `results/`. It contains the Vivado project shell, board bring-up scripts, copied memory initialization files, and experiment evidence.

## Quick Board Flow

Run these from this `results/` directory on a machine with Vivado installed and available in `PATH`.

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

- The scripts add sources from the parent repository (`../src`, `../constraints`) and keep output artifacts in this `results/` submodule.
- `scripts/setup_project.tcl` intentionally excludes `../src/ip/SCPU.v` and `../src/ip/SCPU.edf`, because those are the provided CPU black-box stubs and conflict with the implemented `../src/cpu/SCPU.v`.
- `memory/Test_37_Instr8.dat` and `memory/D_mem.dat` are copied here so Vivado synthesis can resolve `$readmemh("memory/...")` from the project/run directory.
- Generated `.bit`, `.rpt`, `.jou`, and `.log` files are ignored by default. Commit them only if the submission explicitly requires generated artifacts.
