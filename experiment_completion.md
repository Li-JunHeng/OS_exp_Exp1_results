# Exp1 Completion Notes

## Scope

The CPU implementation was expanded from the reference 8-instruction subset to the experiment subset listed in `docs/实验说明文档.docx`:

- R-type: `add`, `sub`, `sll`, `srl`, `sra`, `slt`, `sltu`, `and`, `or`, `xor`
- I-type: `addi`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai`, `slti`, `sltiu`
- U-type: `lui`, `auipc`
- Loads/stores: `lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh`, `sw`
- Branches: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
- Jumps: `jal`, `jalr`

## Verification

Commands run from the parent repository root:

```sh
make test
make top-syntax
```

`make test` passed both cases:

- `rv32i_8_instr`: reached `PC=0x00000048`
- `rv32i_37_instr`: reached `PC=0x00000108`

The 37-instruction run reached the first return from `jalr`, after the arithmetic, shift, compare, little-endian byte/halfword/word memory, branch, `jal`, and `jalr` paths had executed.

## Board Integration

The board-level assembly is `src/board/top.v`.

Use `scripts/vivado_sources.tcl` after creating/opening a Vivado project for Nexys A7-100T. The script adds the implemented CPU sources and the provided IO/IP EDF wrappers, while excluding the unused provided CPU black-box stub.
