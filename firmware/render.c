#include "game.h"

static u32 sprite_slot;

static void sprite_clear(void)
{
    u32 i;

    for (i = 0; i < 32u; i++) {
        VGA_SPRITES[(i << 2) + 3u] = 0;
    }
    sprite_slot = 0;
}

static void sprite_add(s32 x, s32 y, u32 tile)
{
    u32 base;
    s32 sx = x - camera_x;
    s32 sy = y - camera_y;

    if (sprite_slot >= 32u) {
        return;
    }
    if (sx < -16 || sy < -16 || sx > 320 || sy > 240) {
        return;
    }

    base = sprite_slot << 2;
    VGA_SPRITES[base + 0u] = (u32)sx;
    VGA_SPRITES[base + 1u] = (u32)sy;
    VGA_SPRITES[base + 2u] = tile;
    VGA_SPRITES[base + 3u] = 1;
    sprite_slot++;
}

static void fill_tiles(u32 tile)
{
    u32 i;

    VGA_SCROLL = 0;
    VGA_HUD1 = 0;
    for (i = 0; i < TILE_COLS * TILE_ROWS; i++) {
        VGA_TILEMAP[i] = tile;
    }
}

#define PUT_TILE(x, y, ch) (VGA_TILEMAP[(y) * TILE_COLS + (x)] = (u32)(ch))
#define TILE_EMPTY 13u
#define TILE_PANEL 14u
#define TILE_SELECT 15u

static void put_digit(u32 x, u32 y, u32 value)
{
    if (value > 9u) {
        value = 9u;
    }
    PUT_TILE(x, y, '0' + value);
}

static void put_num2(u32 x, u32 y, u32 value)
{
    u32 tens = 0;

    while (value >= 10u && tens < 9u) {
        value -= 10u;
        tens++;
    }
    put_digit(x, y, tens);
    put_digit(x + 1u, y, value);
}

static u32 small_num(s32 value)
{
    if (value < 0) {
        return 0;
    }
    if (value > 15) {
        return 15;
    }
    return (u32)value;
}

static void render_hud(void)
{
    VGA_HUD0 = small_num(player.hp) |
               (small_num(player.max_hp) << 4) |
               (small_num(player.shield) << 8) |
               (small_num(player.armor) << 12) |
               (small_num((s32)player.level) << 16) |
               (small_num(player.attack) << 20) |
               (small_num((s32)player.weapon) << 24) |
               (small_num((s32)floor_id) << 28);
    VGA_HUD1 = 0x80000000u |
               small_num((s32)(room_id + 1u)) |
               (small_num((s32)player.exp) << 4) |
               (small_num((s32)player.next_exp) << 8);
}

void render_init(void)
{
    VGA_PALETTE[0] = 0x000;
    VGA_PALETTE[1] = 0x212;
    VGA_PALETTE[2] = 0x323;
    VGA_PALETTE[3] = 0x545;
    VGA_PALETTE[4] = 0xb24;
    VGA_PALETTE[5] = 0xe74;
    VGA_PALETTE[6] = 0xfc5;
    VGA_PALETTE[7] = 0xfff;
    VGA_PALETTE[8] = 0x7cf;
    VGA_PALETTE[9] = 0x38f;
    VGA_PALETTE[10] = 0xb5f;
    VGA_PALETTE[11] = 0xf5a;
    VGA_PALETTE[12] = 0x865;
    VGA_PALETTE[13] = 0x777;
    VGA_PALETTE[14] = 0xaaa;
    VGA_PALETTE[15] = 0xff5;
    VGA_CTRL = 1;
}

void render_room(void)
{
    u32 x;
    u32 y;
    u32 idx = 0;
    s32 max_camera_x = (DUNGEON_W * 16) - 320;
    s32 max_camera_y = (DUNGEON_H * 16) - 240;
    s32 target_x;
    s32 target_y;
    s32 tile_x;
    s32 tile_y;

    target_x = player.x - 152;
    target_y = player.y - 112;
    if (target_x < 0) target_x = 0;
    if (target_y < 0) target_y = 0;
    if (target_x > max_camera_x) target_x = max_camera_x;
    if (target_y > max_camera_y) target_y = max_camera_y;

    if (camera_x < target_x - 4) camera_x += 4;
    else if (camera_x > target_x + 4) camera_x -= 4;
    else camera_x = target_x;
    if (camera_y < target_y - 4) camera_y += 4;
    else if (camera_y > target_y + 4) camera_y -= 4;
    else camera_y = target_y;

    if (camera_x < 0) camera_x = 0;
    if (camera_y < 0) camera_y = 0;
    if (camera_x > max_camera_x) camera_x = max_camera_x;
    if (camera_y > max_camera_y) camera_y = max_camera_y;

    tile_x = camera_x >> 4;
    tile_y = camera_y >> 4;
    VGA_SCROLL = (u32)((camera_x & 15) | ((camera_y & 15) << 4));

    for (y = 0; y < TILE_ROWS; y++) {
        for (x = 0; x < TILE_COLS; x++) {
            s32 mx = tile_x + (s32)x;
            s32 my = tile_y + (s32)y;
            u32 tile = 0;
            if (mx >= 0 && my >= 0 && mx < DUNGEON_W && my < DUNGEON_H) {
                tile = dungeon_map[(u32)my * DUNGEON_W + (u32)mx];
            }
            VGA_TILEMAP[idx] = tile;
            idx++;
        }
    }
}

void render_title(void)
{
    u32 show_cursor = ((menu_blink >> 4) & 1u) == 0u;

    sprite_clear();
    fill_tiles(0);
    PUT_TILE(5, 2, 'R'); PUT_TILE(6, 2, 'O'); PUT_TILE(7, 2, 'G'); PUT_TILE(8, 2, 'U'); PUT_TILE(9, 2, 'E');
    PUT_TILE(11, 2, 'V'); PUT_TILE(12, 2, 'G'); PUT_TILE(13, 2, 'A');
    if (show_cursor) PUT_TILE(3, 5, '>');
    PUT_TILE(5, 5, 'S'); PUT_TILE(6, 5, 'T'); PUT_TILE(7, 5, 'A'); PUT_TILE(8, 5, 'R'); PUT_TILE(9, 5, 'T');
    PUT_TILE(4, 8, 'W'); PUT_TILE(5, 8, 'A'); PUT_TILE(6, 8, 'S'); PUT_TILE(7, 8, 'D');
    PUT_TILE(9, 8, 'M'); PUT_TILE(10, 8, 'O'); PUT_TILE(11, 8, 'V'); PUT_TILE(12, 8, 'E');
    PUT_TILE(4, 10, 'J'); PUT_TILE(6, 10, 'F'); PUT_TILE(7, 10, 'I'); PUT_TILE(8, 10, 'R'); PUT_TILE(9, 10, 'E');
    PUT_TILE(12, 10, 'K'); PUT_TILE(14, 10, 'R'); PUT_TILE(15, 10, 'O'); PUT_TILE(16, 10, 'L'); PUT_TILE(17, 10, 'L');
    PUT_TILE(4, 12, 'E'); PUT_TILE(5, 12, 'S'); PUT_TILE(6, 12, 'C');
    PUT_TILE(8, 12, 'P'); PUT_TILE(9, 12, 'A'); PUT_TILE(10, 12, 'U'); PUT_TILE(11, 12, 'S'); PUT_TILE(12, 12, 'E');
    GPIO_DISPLAY = 0x53544152u;
}

void render_pause(void)
{
    sprite_clear();
    fill_tiles(0);
    PUT_TILE(7, 4, 'P'); PUT_TILE(8, 4, 'A'); PUT_TILE(9, 4, 'U'); PUT_TILE(10, 4, 'S'); PUT_TILE(11, 4, 'E'); PUT_TILE(12, 4, 'D');
    PUT_TILE(4, 7, 'E'); PUT_TILE(5, 7, 'N'); PUT_TILE(6, 7, 'T'); PUT_TILE(7, 7, 'E'); PUT_TILE(8, 7, 'R');
    PUT_TILE(10, 7, 'R'); PUT_TILE(11, 7, 'E'); PUT_TILE(12, 7, 'S'); PUT_TILE(13, 7, 'U'); PUT_TILE(14, 7, 'M'); PUT_TILE(15, 7, 'E');
    PUT_TILE(3, 10, 'E'); PUT_TILE(4, 10, 'S'); PUT_TILE(5, 10, 'C');
    PUT_TILE(7, 10, 'A'); PUT_TILE(8, 10, 'L'); PUT_TILE(9, 10, 'S'); PUT_TILE(10, 10, 'O');
    PUT_TILE(12, 10, 'R'); PUT_TILE(13, 10, 'E'); PUT_TILE(14, 10, 'S'); PUT_TILE(15, 10, 'U'); PUT_TILE(16, 10, 'M'); PUT_TILE(17, 10, 'E');
    GPIO_DISPLAY = 0x50415553u;
}

void render_dead(void)
{
    sprite_clear();
    fill_tiles(0);
    PUT_TILE(5, 4, 'G'); PUT_TILE(6, 4, 'A'); PUT_TILE(7, 4, 'M'); PUT_TILE(8, 4, 'E');
    PUT_TILE(10, 4, 'O'); PUT_TILE(11, 4, 'V'); PUT_TILE(12, 4, 'E'); PUT_TILE(13, 4, 'R');
    PUT_TILE(3, 8, 'E'); PUT_TILE(4, 8, 'N'); PUT_TILE(5, 8, 'T'); PUT_TILE(6, 8, 'E'); PUT_TILE(7, 8, 'R');
    PUT_TILE(9, 8, 'R'); PUT_TILE(10, 8, 'E'); PUT_TILE(11, 8, 'S'); PUT_TILE(12, 8, 'T'); PUT_TILE(13, 8, 'A'); PUT_TILE(14, 8, 'R'); PUT_TILE(15, 8, 'T');
    GPIO_DISPLAY = 0xDEAD0000u | (player.weapon & 0xffu);
}

void render_levelup(void)
{
    u32 show_cursor = ((menu_blink >> 4) & 1u) == 0u;

    sprite_clear();
    fill_tiles(0);
    PUT_TILE(5, 1, 'L'); PUT_TILE(6, 1, 'E'); PUT_TILE(7, 1, 'V'); PUT_TILE(8, 1, 'E'); PUT_TILE(9, 1, 'L');
    PUT_TILE(11, 1, 'U'); PUT_TILE(12, 1, 'P');
    PUT_TILE(3, 3, 'L'); put_num2(4, 3, player.level);
    PUT_TILE(8, 3, 'E'); put_num2(9, 3, player.exp);
    PUT_TILE(12, 3, 'N'); put_num2(13, 3, player.next_exp);

    if (menu_choice == 0u && show_cursor) PUT_TILE(1, 6, '>');
    PUT_TILE(3, 6, 'M'); PUT_TILE(4, 6, 'A'); PUT_TILE(5, 6, 'X'); PUT_TILE(7, 6, 'H'); PUT_TILE(8, 6, 'P');
    PUT_TILE(11, 6, 'U'); PUT_TILE(12, 6, 'P');
    put_num2(16, 6, (u32)player.max_hp);

    if (menu_choice == 1u && show_cursor) PUT_TILE(1, 8, '>');
    PUT_TILE(3, 8, 'A'); PUT_TILE(4, 8, 'R'); PUT_TILE(5, 8, 'M'); PUT_TILE(6, 8, 'O'); PUT_TILE(7, 8, 'R');
    PUT_TILE(11, 8, 'U'); PUT_TILE(12, 8, 'P');
    put_num2(16, 8, (u32)player.armor);

    if (menu_choice == 2u && show_cursor) PUT_TILE(1, 10, '>');
    PUT_TILE(3, 10, 'A'); PUT_TILE(4, 10, 'T'); PUT_TILE(5, 10, 'T'); PUT_TILE(6, 10, 'A'); PUT_TILE(7, 10, 'C'); PUT_TILE(8, 10, 'K');
    PUT_TILE(11, 10, 'U'); PUT_TILE(12, 10, 'P');
    put_num2(16, 10, (u32)player.attack);

    if (menu_choice == 3u && show_cursor) PUT_TILE(1, 12, '>');
    PUT_TILE(4, 12, 'W'); PUT_TILE(5, 12, 'E'); PUT_TILE(6, 12, 'A'); PUT_TILE(7, 12, 'P'); PUT_TILE(8, 12, 'O'); PUT_TILE(9, 12, 'N');
    PUT_TILE(11, 12, 'U'); PUT_TILE(12, 12, 'P');
    put_num2(16, 12, player.weapon);
    GPIO_DISPLAY = 0x1E000000u | (player.level & 0xffu);
}

void render_game(void)
{
    u32 i;

    if (game_state == GAME_TITLE) {
        render_title();
        return;
    }
    if (game_state == GAME_PAUSED) {
        render_pause();
        return;
    }
    if (game_state == GAME_DEAD) {
        render_dead();
        return;
    }
    if (game_state == GAME_LEVELUP) {
        render_levelup();
        return;
    }

    render_room();
    render_hud();
    sprite_clear();
    sprite_add(player.x, player.y, 5);

    for (i = 0; i < MAX_ENEMIES; i++) {
        if (enemies[i].active) {
            sprite_add(enemies[i].x, enemies[i].y, 6);
        }
    }
    for (i = 0; i < MAX_BULLETS; i++) {
        if (bullets[i].active) {
            sprite_add(bullets[i].x, bullets[i].y, bullets[i].kind ? 16u : 8u);
        }
    }
    for (i = 0; i < MAX_PICKUPS; i++) {
        if (pickups[i].active) {
            sprite_add(pickups[i].x, pickups[i].y, 7);
        }
    }

    GPIO_LED = ((player.hp & 0xffu) << 8) | ((room_id + 1u) & 0xffu);
    GPIO_DISPLAY = (floor_id << 24) | (room_id << 16) | ((u32)player.hp << 8) | player.weapon;
}
