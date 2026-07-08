#include "game.h"

volatile u32 key_state[KEY_COUNT];

static u32 ps2_break;
static u32 ps2_ext;

static void set_key(u32 key, u32 down)
{
    if (key < KEY_COUNT) {
        key_state[key] = down;
    }
}

static void handle_scan(u8 code)
{
    u32 down;

    if (code == 0xe0) {
        ps2_ext = 1;
        return;
    }
    if (code == 0xf0) {
        ps2_break = 1;
        return;
    }

    down = ps2_break ? 0u : 1u;

    if (ps2_ext) {
        if (code == 0x75) set_key(KEY_UP, down);
        else if (code == 0x72) set_key(KEY_DOWN, down);
        else if (code == 0x6b) set_key(KEY_LEFT, down);
        else if (code == 0x74) set_key(KEY_RIGHT, down);
    } else {
        if (code == 0x1d) set_key(KEY_UP, down);       /* W */
        else if (code == 0x1b) set_key(KEY_DOWN, down); /* S */
        else if (code == 0x1c) set_key(KEY_LEFT, down); /* A */
        else if (code == 0x23) set_key(KEY_RIGHT, down);/* D */
        else if (code == 0x29) set_key(KEY_FIRE, down); /* Space */
        else if (code == 0x3b) set_key(KEY_FIRE, down); /* J */
        else if (code == 0x42) set_key(KEY_ROLL, down); /* K */
        else if (code == 0x5a) set_key(KEY_CONFIRM, down);
        else if (code == 0x76) set_key(KEY_PAUSE, down);
    }

    ps2_break = 0;
    ps2_ext = 0;
}

void input_handle_ps2_irq(void)
{
    u32 guard = 16;

    while ((PS2_STATUS & 1u) && guard) {
        handle_scan((u8)PS2_DATA);
        guard--;
    }

    if (PS2_STATUS & 0x1cu) {
        PS2_STATUS = 0x1cu;
    }
}

void input_poll(void)
{
    input_handle_ps2_irq();
}
