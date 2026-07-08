#ifndef GAME_H
#define GAME_H

#include "mmio.h"

#define TILE_COLS 21
#define TILE_ROWS 16
#define MAX_ENEMIES 8
#define MAX_BULLETS 12
#define MAX_PICKUPS 6
#define DUNGEON_W 52
#define DUNGEON_H 38
#define DUNGEON_ROOMS 6

#define GAME_TITLE   0u
#define GAME_PLAYING 1u
#define GAME_PAUSED  2u
#define GAME_DEAD    3u
#define GAME_LEVELUP 4u

enum {
    KEY_UP = 0,
    KEY_DOWN,
    KEY_LEFT,
    KEY_RIGHT,
    KEY_FIRE,
    KEY_ROLL,
    KEY_CONFIRM,
    KEY_PAUSE,
    KEY_COUNT
};

typedef struct {
    s32 x;
    s32 y;
    s32 hp;
    s32 max_hp;
    s32 armor;
    s32 shield;
    s32 attack;
    u32 level;
    u32 exp;
    u32 next_exp;
    u32 weapon;
    u32 invuln;
    u32 fire_cd;
    u32 roll_cd;
} Player;

typedef struct {
    s32 x;
    s32 y;
    s32 vx;
    s32 vy;
    s32 hp;
    u32 fire_cd;
    u32 active;
} Enemy;

typedef struct {
    s32 x;
    s32 y;
    s32 vx;
    s32 vy;
    u32 ttl;
    u32 kind;
    u32 active;
} Bullet;

typedef struct {
    s32 x;
    s32 y;
    u32 kind;
    u32 active;
} Pickup;

extern volatile u32 key_state[KEY_COUNT];

extern Player player;
extern Enemy enemies[MAX_ENEMIES];
extern Bullet bullets[MAX_BULLETS];
extern Pickup pickups[MAX_PICKUPS];
extern u32 floor_id;
extern u32 room_id;
extern u32 rng_state;
extern u32 game_state;
extern u32 menu_choice;
extern u32 menu_blink;
extern u8 dungeon_map[DUNGEON_W * DUNGEON_H];
extern s32 camera_x;
extern s32 camera_y;

void input_handle_ps2_irq(void);
void input_poll(void);
void render_init(void);
void render_room(void);
void render_title(void);
void render_pause(void);
void render_dead(void);
void render_levelup(void);
void render_game(void);
void world_init(void);
void world_start(void);
void world_next_room(void);
u32 world_is_solid_px(s32 x, s32 y);
void world_update_current_room(void);
void world_mark_current_room_clear(void);
u32 world_current_room_cleared(void);
u32 world_all_rooms_cleared(void);

#endif
