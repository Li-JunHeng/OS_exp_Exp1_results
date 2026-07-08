#include "game.h"

#define MAP_IDX(x, y) ((u32)(y) * DUNGEON_W + (u32)(x))
#define TILE_VOID 0u
#define TILE_FLOOR 1u
#define TILE_WALL 2u

typedef struct {
    u8 x;
    u8 y;
    u8 w;
    u8 h;
} RoomDef;

u32 floor_id;
u32 room_id;
u32 rng_state;
u32 game_state;
u8 dungeon_map[DUNGEON_W * DUNGEON_H];
s32 camera_x;
s32 camera_y;

static RoomDef rooms[DUNGEON_ROOMS];
static u32 room_clear_mask;

static s32 abs32_local(s32 v)
{
    return (v < 0) ? -v : v;
}

static u32 rnd(void)
{
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

static u32 rnd_range(u32 span)
{
    u32 value = rnd() & 0xffu;

    while (value >= span) {
        value -= span;
    }
    return value;
}

static void clear_objects(void)
{
    u32 i;

    for (i = 0; i < MAX_ENEMIES; i++) {
        enemies[i].active = 0;
    }
    for (i = 0; i < MAX_BULLETS; i++) {
        bullets[i].active = 0;
    }
    for (i = 0; i < MAX_PICKUPS; i++) {
        pickups[i].active = 0;
    }
}

static void fill_dungeon(u8 tile)
{
    u32 i;

    for (i = 0; i < DUNGEON_W * DUNGEON_H; i++) {
        dungeon_map[i] = tile;
    }
}

static void carve_tile(s32 x, s32 y, u8 tile)
{
    if (x > 0 && y > 0 && x < (s32)(DUNGEON_W - 1) && y < (s32)(DUNGEON_H - 1)) {
        dungeon_map[MAP_IDX(x, y)] = tile;
    }
}

static void carve_wall_if_void(s32 x, s32 y)
{
    if (x > 0 && y > 0 && x < (s32)(DUNGEON_W - 1) && y < (s32)(DUNGEON_H - 1) &&
        dungeon_map[MAP_IDX(x, y)] == TILE_VOID) {
        dungeon_map[MAP_IDX(x, y)] = TILE_WALL;
    }
}

static void carve_room(u32 id)
{
    s32 x;
    s32 y;
    RoomDef *r = &rooms[id];

    for (y = (s32)r->y; y < (s32)(r->y + r->h); y++) {
        for (x = (s32)r->x; x < (s32)(r->x + r->w); x++) {
            if (x == r->x || y == r->y || x == (s32)(r->x + r->w - 1u) || y == (s32)(r->y + r->h - 1u)) {
                carve_tile(x, y, TILE_WALL);
            } else {
                carve_tile(x, y, TILE_FLOOR);
            }
        }
    }
}

static void carve_h_corridor(s32 x0, s32 x1, s32 y)
{
    s32 x;
    s32 step = (x0 <= x1) ? 1 : -1;

    for (x = x0; x != x1 + step; x += step) {
        carve_wall_if_void(x, y - 1);
        carve_tile(x, y, TILE_FLOOR);
        carve_tile(x, y + 1, TILE_FLOOR);
        carve_wall_if_void(x, y + 2);
    }
}

static void carve_v_corridor(s32 y0, s32 y1, s32 x)
{
    s32 y;
    s32 step = (y0 <= y1) ? 1 : -1;

    for (y = y0; y != y1 + step; y += step) {
        carve_wall_if_void(x - 1, y);
        carve_tile(x, y, TILE_FLOOR);
        carve_tile(x + 1, y, TILE_FLOOR);
        carve_wall_if_void(x + 2, y);
    }
}

static s32 clamp_to_room_inner(s32 v, s32 start, s32 size)
{
    s32 lo = start + 2;
    s32 hi = start + size - 4;

    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static void carve_h_opening(s32 x, s32 y)
{
    carve_tile(x, y, TILE_FLOOR);
    carve_tile(x, y + 1, TILE_FLOOR);
}

static void carve_v_opening(s32 x, s32 y)
{
    carve_tile(x, y, TILE_FLOOR);
    carve_tile(x + 1, y, TILE_FLOOR);
}

static void connect_rooms(u32 a, u32 b)
{
    s32 acx = (s32)rooms[a].x + ((s32)rooms[a].w >> 1);
    s32 acy = (s32)rooms[a].y + ((s32)rooms[a].h >> 1);
    s32 bcx = (s32)rooms[b].x + ((s32)rooms[b].w >> 1);
    s32 bcy = (s32)rooms[b].y + ((s32)rooms[b].h >> 1);
    s32 dx = bcx - acx;
    s32 dy = bcy - acy;
    s32 ax;
    s32 ay;
    s32 bx;
    s32 by;

    if (abs32_local(dx) >= abs32_local(dy)) {
        ay = clamp_to_room_inner(acy, rooms[a].y, rooms[a].h);
        by = clamp_to_room_inner(bcy, rooms[b].y, rooms[b].h);
        if (dx >= 0) {
            ax = (s32)rooms[a].x + (s32)rooms[a].w - 1;
            bx = (s32)rooms[b].x;
        } else {
            ax = (s32)rooms[a].x;
            bx = (s32)rooms[b].x + (s32)rooms[b].w - 1;
        }
        carve_h_opening(ax, ay);
        carve_h_opening(bx, by);
        carve_h_corridor(ax, bx, ay);
        carve_v_corridor(ay, by, bx);
    } else {
        ax = clamp_to_room_inner(acx, rooms[a].x, rooms[a].w);
        bx = clamp_to_room_inner(bcx, rooms[b].x, rooms[b].w);
        if (dy >= 0) {
            ay = (s32)rooms[a].y + (s32)rooms[a].h - 1;
            by = (s32)rooms[b].y;
        } else {
            ay = (s32)rooms[a].y;
            by = (s32)rooms[b].y + (s32)rooms[b].h - 1;
        }
        carve_v_opening(ax, ay);
        carve_v_opening(bx, by);
        carve_v_corridor(ay, by, ax);
        carve_h_corridor(ax, bx, by);
    }
}

static void generate_dungeon(void)
{
    u32 i;

    fill_dungeon(TILE_VOID);
    for (i = 0; i < DUNGEON_ROOMS; i++) {
        u32 base_x = 2u;
        u32 base_y = 2u;

        if (i == 1u) { base_x = 20u; base_y = 3u; }
        else if (i == 2u) { base_x = 38u; base_y = 2u; }
        else if (i == 3u) { base_x = 5u; base_y = 24u; }
        else if (i == 4u) { base_x = 23u; base_y = 25u; }
        else if (i == 5u) { base_x = 39u; base_y = 22u; }

        rooms[i].w = (u8)(10u + rnd_range(4u));
        rooms[i].h = (u8)(8u + rnd_range(3u));
        rooms[i].x = (u8)(base_x + rnd_range(3u));
        rooms[i].y = (u8)(base_y + rnd_range(3u));
        if ((u32)rooms[i].x + rooms[i].w >= DUNGEON_W - 1u) rooms[i].x = DUNGEON_W - rooms[i].w - 2u;
        if ((u32)rooms[i].y + rooms[i].h >= DUNGEON_H - 1u) rooms[i].y = DUNGEON_H - rooms[i].h - 2u;
        carve_room(i);
    }

    for (i = 1; i < DUNGEON_ROOMS; i++) {
        connect_rooms(i - 1u, i);
    }
    connect_rooms(0u, 3u);
    connect_rooms(2u, 5u);
    room_clear_mask = 0;
}

static void init_player(void)
{
    player.max_hp = 8;
    player.hp = player.max_hp;
    player.armor = 2;
    player.shield = player.armor;
    player.attack = 1;
    player.level = 1;
    player.exp = 0;
    player.next_exp = 6;
    player.weapon = 1;
    player.invuln = 0;
    player.fire_cd = 0;
    player.roll_cd = 0;
}

static void place_player_in_room(u32 id)
{
    player.x = (((s32)rooms[id].x + ((s32)rooms[id].w >> 1)) << 4);
    player.y = (((s32)rooms[id].y + ((s32)rooms[id].h >> 1)) << 4);
}

static u32 point_in_room(u32 id, s32 tx, s32 ty)
{
    return tx >= rooms[id].x && ty >= rooms[id].y &&
           tx < (s32)(rooms[id].x + rooms[id].w) &&
           ty < (s32)(rooms[id].y + rooms[id].h);
}

static void spawn_current_room(void)
{
    u32 i;
    u32 tries;
    u32 count;
    RoomDef *r;

    if (room_clear_mask & (1u << room_id)) {
        return;
    }

    clear_objects();
    count = 2u + ((room_id + floor_id) & 3u);
    if (room_id == DUNGEON_ROOMS - 1u) {
        count = 1u;
    }
    r = &rooms[room_id];

    for (i = 0; i < count && i < MAX_ENEMIES; i++) {
        s32 tx = (s32)r->x + 2;
        s32 ty = (s32)r->y + 2;

        for (tries = 0; tries < 16u; tries++) {
            tx = (s32)r->x + 2 + (s32)rnd_range(r->w - 4u);
            ty = (s32)r->y + 2 + (s32)rnd_range(r->h - 4u);
            if (!world_is_solid_px(tx << 4, ty << 4) &&
                !world_is_solid_px((tx << 4) + 15, (ty << 4) + 15)) {
                break;
            }
        }
        enemies[i].active = 1;
        enemies[i].x = tx << 4;
        enemies[i].y = ty << 4;
        enemies[i].vx = 0;
        enemies[i].vy = 0;
        enemies[i].fire_cd = 20u + (rnd() & 31u);
        enemies[i].hp = (room_id == DUNGEON_ROOMS - 1u) ? (18 + (s32)(floor_id << 1)) : (3 + (s32)floor_id);
    }
}

u32 world_is_solid_px(s32 x, s32 y)
{
    s32 tx = x >> 4;
    s32 ty = y >> 4;
    u8 tile;

    if (tx < 0 || ty < 0 || tx >= DUNGEON_W || ty >= DUNGEON_H) {
        return 1;
    }
    tile = dungeon_map[MAP_IDX(tx, ty)];
    return tile == TILE_VOID || tile == TILE_WALL;
}

void world_update_current_room(void)
{
    u32 i;
    s32 tx = (player.x + 8) >> 4;
    s32 ty = (player.y + 8) >> 4;

    for (i = 0; i < DUNGEON_ROOMS; i++) {
        if (point_in_room(i, tx, ty)) {
            if (room_id != i) {
                room_id = i;
                spawn_current_room();
            }
            return;
        }
    }
}

void world_mark_current_room_clear(void)
{
    room_clear_mask |= (1u << room_id);
}

u32 world_current_room_cleared(void)
{
    return (room_clear_mask & (1u << room_id)) != 0u;
}

u32 world_all_rooms_cleared(void)
{
    return (room_clear_mask & ((1u << DUNGEON_ROOMS) - 1u)) == ((1u << DUNGEON_ROOMS) - 1u);
}

void world_init(void)
{
    floor_id = 1;
    room_id = 0;
    rng_state = 0x12345678u;
    game_state = GAME_TITLE;
    camera_x = 0;
    camera_y = 0;

    init_player();
    clear_objects();
}

void world_start(void)
{
    floor_id = 1;
    room_id = 0;
    rng_state = 0x12345678u;
    game_state = GAME_PLAYING;

    init_player();
    generate_dungeon();
    place_player_in_room(0);
    clear_objects();
    spawn_current_room();
    render_room();
}

void world_next_room(void)
{
    floor_id++;
    room_id = 0;
    rng_state ^= floor_id * 0x9e37u;
    if (player.hp < player.max_hp) {
        player.hp++;
    }
    player.shield = player.armor;
    generate_dungeon();
    place_player_in_room(0);
    clear_objects();
    spawn_current_room();
    render_room();
}
