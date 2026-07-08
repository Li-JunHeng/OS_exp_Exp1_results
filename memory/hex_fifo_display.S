// PS/2 hexadecimal FIFO display demo loaded through memory/testac.dat.
//
// im.v reads memory/testac.dat with $readmemh. The matching testac.coe is kept
// in sync for Vivado memory-core workflows, but the board build uses the .dat.
//
// Use sw[7:5] = 011 to view display_value as eight hexadecimal digits.
//
// The program polls the PS/2 keyboard FIFO:
//   0xd0000004 bit 0: data_valid
//   0xd0000000: read one scan code and pop the FIFO
//
// Accepted Set-2 scan codes:
//   0:45 1:16 2:1e 3:26 4:25 5:2e 6:36 7:3d
//   8:3e 9:46 A:1c B:32 C:21 D:23 E:24 F:2b
//
// Every accepted key is appended to an 8-nibble FIFO:
//   display_value = (display_value << 4) | hex_nibble
// Non-hex scan codes, including break prefix f0 and extended prefix e0, are
// consumed and ignored.

.equ DISPLAY,    0xe0000000
.equ PS2_DATA,   0xd0000000
.equ PS2_STATUS, 0xd0000004

.org 0x000
boot:
    lui   x1, 0xe0000       // display register
    lui   x2, 0xd0000       // PS/2 base
    addi  x10, x0, 0        // 8-nibble FIFO value
    nop
    nop
    nop
    nop
    sw    x10, 0(x1)

poll:
    lw    x11, 4(x2)        // PS/2 status
    nop
    nop
    nop
    nop
    andi  x11, x11, 1
    nop
    nop
    nop
    nop
    beq   x11, x0, poll

    lw    x12, 0(x2)        // pop one scan code
    nop
    nop
    nop
    nop
    andi  x12, x12, 255
    nop
    nop
    nop
    nop

    addi  x13, x0, 0x45
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_0
    addi  x13, x0, 0x16
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_1
    addi  x13, x0, 0x1e
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_2
    addi  x13, x0, 0x26
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_3
    addi  x13, x0, 0x25
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_4
    addi  x13, x0, 0x2e
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_5
    addi  x13, x0, 0x36
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_6
    addi  x13, x0, 0x3d
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_7
    addi  x13, x0, 0x3e
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_8
    addi  x13, x0, 0x46
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_9
    addi  x13, x0, 0x1c
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_a
    addi  x13, x0, 0x32
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_b
    addi  x13, x0, 0x21
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_c
    addi  x13, x0, 0x23
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_d
    addi  x13, x0, 0x24
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_e
    addi  x13, x0, 0x2b
    nop
    nop
    nop
    nop
    beq   x12, x13, hex_f
    jal   x0, poll

hex_0: addi x14, x0, 0
       jal  x0, push_hex
hex_1: addi x14, x0, 1
       jal  x0, push_hex
hex_2: addi x14, x0, 2
       jal  x0, push_hex
hex_3: addi x14, x0, 3
       jal  x0, push_hex
hex_4: addi x14, x0, 4
       jal  x0, push_hex
hex_5: addi x14, x0, 5
       jal  x0, push_hex
hex_6: addi x14, x0, 6
       jal  x0, push_hex
hex_7: addi x14, x0, 7
       jal  x0, push_hex
hex_8: addi x14, x0, 8
       jal  x0, push_hex
hex_9: addi x14, x0, 9
       jal  x0, push_hex
hex_a: addi x14, x0, 10
       jal  x0, push_hex
hex_b: addi x14, x0, 11
       jal  x0, push_hex
hex_c: addi x14, x0, 12
       jal  x0, push_hex
hex_d: addi x14, x0, 13
       jal  x0, push_hex
hex_e: addi x14, x0, 14
       jal  x0, push_hex
hex_f: addi x14, x0, 15
       jal  x0, push_hex

push_hex:
    nop
    nop
    nop
    nop
    slli  x10, x10, 4
    nop
    nop
    nop
    nop
    or    x10, x10, x14
    nop
    nop
    nop
    nop
    sw    x10, 0(x1)
    jal   x0, poll
