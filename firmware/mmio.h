#ifndef MMIO_H
#define MMIO_H

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef int s32;

#define VGA_CTRL       (*(volatile u32 *)0xc0000000u)
#define VGA_STATUS     (*(volatile u32 *)0xc0000004u)
#define VGA_SCROLL     (*(volatile u32 *)0xc0000008u)
#define VGA_HUD0       (*(volatile u32 *)0xc000000cu)
#define VGA_HUD1       (*(volatile u32 *)0xc0000010u)
#define VGA_TILEMAP    ((volatile u32 *)0xc0000100u)
#define VGA_SPRITES    ((volatile u32 *)0xc0001000u)
#define VGA_PALETTE    ((volatile u32 *)0xc0002000u)

#define PS2_DATA       (*(volatile u32 *)0xd0000000u)
#define PS2_STATUS     (*(volatile u32 *)0xd0000004u)

#define GPIO_DISPLAY   (*(volatile u32 *)0xe0000000u)
#define GPIO_LED       (*(volatile u32 *)0xf0000000u)

#define MSTATUS_MIE    (1u << 3)
#define MIE_MTIE       (1u << 7)
#define MIE_MEIE       (1u << 11)

#define CAUSE_MTI      0x80000007u
#define CAUSE_MEI      0x8000000bu

#define PLIC_ID_KEYBOARD 5u

static inline void cpu_nops(void)
{
    __asm__ volatile ("nop\nnop\nnop\nnop");
}

static inline void csr_write_mstatus(u32 value)
{
    __asm__ volatile ("csrw mstatus, %0" :: "r"(value));
    cpu_nops();
}

static inline void csr_write_mie(u32 value)
{
    __asm__ volatile ("csrw mie, %0" :: "r"(value));
    cpu_nops();
}

static inline void csr_write_mtvec(u32 value)
{
    __asm__ volatile ("csrw mtvec, %0" :: "r"(value));
    cpu_nops();
}

static inline u32 plic_claim(void)
{
    u32 value;
    __asm__ volatile ("csrr %0, 0x7d2" : "=r"(value));
    cpu_nops();
    return value;
}

static inline void plic_complete(u32 value)
{
    __asm__ volatile ("csrw 0x7d2, %0" :: "r"(value));
    cpu_nops();
}

static inline void plic_enable(u32 value)
{
    __asm__ volatile ("csrw 0x7d1, %0" :: "r"(value));
    cpu_nops();
}

#endif
