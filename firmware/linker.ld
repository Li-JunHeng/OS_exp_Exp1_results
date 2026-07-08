OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw)  : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.boot))
        *(.text .text.*)
    } > IMEM

    .rodata : {
        *(.rodata .rodata.*)
    } > IMEM

    .data : {
        *(.data .data.*)
    } > DMEM

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > DMEM

    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
