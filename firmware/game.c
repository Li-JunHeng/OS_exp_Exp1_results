#include "game.h"

Player player;
Enemy enemies[MAX_ENEMIES];
Bullet bullets[MAX_BULLETS];
Pickup pickups[MAX_PICKUPS];
u32 menu_choice;
u32 menu_blink;

static s32 aim_x;
static s32 aim_y;
static u32 pause_latch;
static u32 confirm_latch;
static u32 nav_latch;

static s32 abs32(s32 v)
{
    return (v < 0) ? -v : v;
}

static u32 overlap(s32 ax, s32 ay, s32 bx, s32 by)
{
    return (abs32(ax - bx) < 14) && (abs32(ay - by) < 14);
}

static u32 body_blocked(s32 x, s32 y)
{
    return world_is_solid_px(x + 3, y + 3) ||
           world_is_solid_px(x + 12, y + 3) ||
           world_is_solid_px(x + 3, y + 12) ||
           world_is_solid_px(x + 12, y + 12);
}

static s32 sign_step(s32 v);

static s32 signed_speed(s32 sign, s32 speed)
{
    if (sign > 0) return speed;
    if (sign < 0) return -speed;
    return 0;
}

static s32 clamp_speed(s32 v)
{
    if (v > 4) return 4;
    if (v < -4) return -4;
    return v;
}

static void set_homing_velocity(Bullet *b, Enemy *e)
{
    s32 dx = e->x - b->x;
    s32 dy = e->y - b->y;
    s32 adx = abs32(dx);
    s32 ady = abs32(dy);
    s32 sx = sign_step(dx);
    s32 sy = sign_step(dy);

    if (adx > (ady << 1)) {
        b->vx = signed_speed(sx, 4);
        b->vy = sy;
    } else if (ady > (adx << 1)) {
        b->vx = sx;
        b->vy = signed_speed(sy, 4);
    } else {
        b->vx = signed_speed(sx, 3);
        b->vy = signed_speed(sy, 3);
    }
}

static u32 all_rooms_cleared(void)
{
    return world_all_rooms_cleared();
}

static u32 alloc_pickup(s32 x, s32 y, u32 kind)
{
    u32 i;

    for (i = 0; i < MAX_PICKUPS; i++) {
        if (!pickups[i].active) {
            pickups[i].active = 1;
            pickups[i].x = x;
            pickups[i].y = y;
            pickups[i].kind = kind;
            return 1;
        }
    }
    return 0;
}

static s32 sign_step(s32 v)
{
    if (v > 0) return 1;
    if (v < 0) return -1;
    return 0;
}

static void damage_player(void)
{
    if (player.invuln != 0) {
        return;
    }
    if (player.shield > 0) {
        player.shield--;
    } else if (player.hp > 0) {
        player.hp--;
    }
    player.invuln = 45;
    if (player.hp <= 0) {
        game_state = GAME_DEAD;
    }
}

static u32 alloc_bullet(s32 x, s32 y, s32 vx, s32 vy, u32 ttl, u32 kind)
{
    u32 i;

    for (i = 0; i < MAX_BULLETS; i++) {
        if (!bullets[i].active) {
            bullets[i].active = 1;
            bullets[i].x = x;
            bullets[i].y = y;
            bullets[i].vx = clamp_speed(vx);
            bullets[i].vy = clamp_speed(vy);
            bullets[i].ttl = ttl;
            bullets[i].kind = kind;
            return 1;
        }
    }
    return 0;
}

static void fire_bullet(void)
{
    s32 vx = aim_x;
    s32 vy = aim_y;

    if (player.fire_cd) {
        return;
    }
    if (vx == 0 && vy == 0) {
        vx = 3;
    }

    if (alloc_bullet(player.x + 4, player.y + 4, vx, vy, 90, 0)) {
        player.fire_cd = 13u;
        if (player.weapon >= 2u) player.fire_cd = 10u;
        if (player.weapon >= 4u) player.fire_cd = 7u;
        if (player.weapon >= 6u) player.fire_cd = 5u;
    }
}

static void update_player(void)
{
    s32 dx = 0;
    s32 dy = 0;
    s32 speed = 2;

    if (key_state[KEY_LEFT]) dx -= speed;
    if (key_state[KEY_RIGHT]) dx += speed;
    if (key_state[KEY_UP]) dy -= speed;
    if (key_state[KEY_DOWN]) dy += speed;

    if (key_state[KEY_ROLL] && player.roll_cd == 0) {
        dx = dx << 2;
        dy = dy << 2;
        player.invuln = 20;
        player.roll_cd = 45;
    }

    if (dx || dy) {
        aim_x = sign_step(dx) * 3;
        aim_y = sign_step(dy) * 3;
    }

    if (!body_blocked(player.x + dx, player.y)) {
        player.x += dx;
    }
    if (!body_blocked(player.x, player.y + dy)) {
        player.y += dy;
    }
    world_update_current_room();

    if (key_state[KEY_FIRE]) {
        fire_bullet();
    }
    if (player.fire_cd) player.fire_cd--;
    if (player.roll_cd) player.roll_cd--;
    if (player.invuln) player.invuln--;
}

static void gain_exp(u32 amount)
{
    player.exp += amount;
    if (player.exp >= player.next_exp && game_state == GAME_PLAYING) {
        player.exp -= player.next_exp;
        player.level++;
        player.next_exp += 4u;
        menu_choice = 0;
        game_state = GAME_LEVELUP;
    }
}

static u32 nearest_enemy(s32 x, s32 y)
{
    u32 i;
    u32 best = MAX_ENEMIES;
    s32 best_dist = 32767;

    for (i = 0; i < MAX_ENEMIES; i++) {
        if (enemies[i].active) {
            s32 dx = abs32(enemies[i].x - x);
            s32 dy = abs32(enemies[i].y - y);
            s32 dist = dx + dy;
            if (dist < best_dist) {
                best_dist = dist;
                best = i;
            }
        }
    }
    return best;
}

static void update_bullets(void)
{
    u32 i;
    u32 j;

    for (i = 0; i < MAX_BULLETS; i++) {
        if (!bullets[i].active) {
            continue;
        }
        j = nearest_enemy(bullets[i].x, bullets[i].y);
        if (bullets[i].kind == 0u && j < MAX_ENEMIES) {
            set_homing_velocity(&bullets[i], &enemies[j]);
        }
        if (bullets[i].vx == 0 && bullets[i].vy == 0) {
            bullets[i].vx = 3;
        }
        bullets[i].x += bullets[i].vx;
        bullets[i].y += bullets[i].vy;
        if (bullets[i].ttl) bullets[i].ttl--;
        if (!bullets[i].ttl || world_is_solid_px(bullets[i].x + 8, bullets[i].y + 8)) {
            bullets[i].active = 0;
            continue;
        }

        if (bullets[i].kind != 0u) {
            if (overlap(bullets[i].x, bullets[i].y, player.x, player.y)) {
                bullets[i].active = 0;
                damage_player();
            }
        } else {
            for (j = 0; j < MAX_ENEMIES; j++) {
                if (enemies[j].active && overlap(bullets[i].x, bullets[i].y, enemies[j].x, enemies[j].y)) {
                    bullets[i].active = 0;
                    enemies[j].hp -= player.attack + (s32)(player.weapon >> 1);
                    if (enemies[j].hp <= 0) {
                        enemies[j].active = 0;
                        gain_exp((room_id == 5u) ? 6u : 2u);
                        alloc_pickup(enemies[j].x, enemies[j].y, 1);
                    }
                    break;
                }
            }
        }
    }
}

static void enemy_fire(u32 i)
{
    s32 dx = sign_step(player.x - enemies[i].x) * 2;
    s32 dy = sign_step(player.y - enemies[i].y) * 2;

    if (dx == 0 && dy == 0) {
        dx = 2;
    }
    if (alloc_bullet(enemies[i].x + 4, enemies[i].y + 4, dx, dy, 110, 1)) {
        enemies[i].fire_cd = 55u + ((u32)i << 2);
    }
}

static void separate_enemies(void)
{
    u32 i;
    u32 j;

    for (i = 0; i < MAX_ENEMIES; i++) {
        if (!enemies[i].active) {
            continue;
        }
        for (j = i + 1u; j < MAX_ENEMIES; j++) {
            if (enemies[j].active && overlap(enemies[i].x, enemies[i].y, enemies[j].x, enemies[j].y)) {
                s32 push_x = sign_step(enemies[i].x - enemies[j].x);
                s32 push_y = sign_step(enemies[i].y - enemies[j].y);
                if (push_x == 0 && push_y == 0) {
                    push_x = (i & 1u) ? 1 : -1;
                }
                if (!body_blocked(enemies[i].x + push_x, enemies[i].y)) enemies[i].x += push_x;
                if (!body_blocked(enemies[j].x - push_x, enemies[j].y)) enemies[j].x -= push_x;
                if (!body_blocked(enemies[i].x, enemies[i].y + push_y)) enemies[i].y += push_y;
                if (!body_blocked(enemies[j].x, enemies[j].y - push_y)) enemies[j].y -= push_y;
            }
        }
    }
}

static void update_enemies(void)
{
    u32 i;

    for (i = 0; i < MAX_ENEMIES; i++) {
        if (!enemies[i].active) {
            continue;
        }
        {
            s32 dist = abs32(player.x - enemies[i].x) + abs32(player.y - enemies[i].y);
            if (dist > 110) {
                enemies[i].vx = sign_step(player.x - enemies[i].x);
                enemies[i].vy = sign_step(player.y - enemies[i].y);
            } else if (dist < 58) {
                enemies[i].vx = -sign_step(player.x - enemies[i].x);
                enemies[i].vy = -sign_step(player.y - enemies[i].y);
            } else {
                enemies[i].vx = 0;
                enemies[i].vy = 0;
            }
        }
        if (!body_blocked(enemies[i].x + enemies[i].vx, enemies[i].y)) {
            enemies[i].x += enemies[i].vx;
        }
        if (!body_blocked(enemies[i].x, enemies[i].y + enemies[i].vy)) {
            enemies[i].y += enemies[i].vy;
        }

        if (overlap(enemies[i].x, enemies[i].y, player.x, player.y) && player.invuln == 0) {
            damage_player();
        }

        if (enemies[i].fire_cd) {
            enemies[i].fire_cd--;
        } else {
            enemy_fire(i);
        }
    }
    separate_enemies();
}

static void update_pickups(void)
{
    u32 i;

    for (i = 0; i < MAX_PICKUPS; i++) {
        if (pickups[i].active && overlap(pickups[i].x, pickups[i].y, player.x, player.y)) {
            pickups[i].active = 0;
            if (player.shield < player.armor) {
                player.shield++;
            } else if (player.hp < player.max_hp) {
                player.hp++;
            }
        }
    }
}

static u32 enemies_alive(void)
{
    u32 i;
    u32 alive = 0;

    for (i = 0; i < MAX_ENEMIES; i++) {
        alive |= enemies[i].active;
    }
    return alive;
}

static void update_game(void)
{
    menu_blink++;

    if (game_state == GAME_TITLE) {
        menu_choice = 0;
        if (key_state[KEY_CONFIRM]) {
            if (!confirm_latch) {
                world_start();
                aim_x = 3;
                aim_y = 0;
                confirm_latch = 1;
            }
        } else {
            confirm_latch = 0;
        }
        return;
    }

    if (game_state == GAME_LEVELUP) {
        if ((key_state[KEY_UP] || key_state[KEY_LEFT]) && !nav_latch) {
            menu_choice = (menu_choice == 0u) ? 3u : (menu_choice - 1u);
            nav_latch = 1;
        } else if ((key_state[KEY_DOWN] || key_state[KEY_RIGHT]) && !nav_latch) {
            menu_choice++;
            if (menu_choice >= 4u) {
                menu_choice = 0;
            }
            nav_latch = 1;
        } else if (!key_state[KEY_UP] && !key_state[KEY_DOWN] &&
                   !key_state[KEY_LEFT] && !key_state[KEY_RIGHT]) {
            nav_latch = 0;
        }

        if (key_state[KEY_CONFIRM] && !confirm_latch) {
            if (menu_choice == 0u) {
                player.max_hp += 2;
                player.hp += 2;
            } else if (menu_choice == 1u) {
                player.armor++;
                player.shield = player.armor;
            } else if (menu_choice == 2u) {
                player.attack++;
            } else {
                player.weapon++;
            }
            game_state = GAME_PLAYING;
            render_room();
            confirm_latch = 1;
        } else if (!key_state[KEY_CONFIRM]) {
            confirm_latch = 0;
        }
        return;
    }

    if (game_state == GAME_DEAD) {
        if (key_state[KEY_CONFIRM]) {
            if (!confirm_latch) {
                world_start();
                aim_x = 3;
                aim_y = 0;
                confirm_latch = 1;
            }
        } else {
            confirm_latch = 0;
        }
        return;
    }

    if (game_state == GAME_PAUSED) {
        if (key_state[KEY_CONFIRM] && !confirm_latch) {
            game_state = GAME_PLAYING;
            render_room();
            confirm_latch = 1;
        } else if (!key_state[KEY_CONFIRM]) {
            confirm_latch = 0;
        }
    }

    if (key_state[KEY_PAUSE]) {
        if (!pause_latch) {
            if (game_state == GAME_PLAYING) {
                game_state = GAME_PAUSED;
            } else if (game_state == GAME_PAUSED) {
                game_state = GAME_PLAYING;
                render_room();
            }
            pause_latch = 1;
        }
    } else {
        pause_latch = 0;
    }

    if (game_state != GAME_PLAYING) {
        return;
    }

    update_player();
    update_bullets();
    update_enemies();
    update_pickups();

    if (!enemies_alive() && !world_current_room_cleared()) {
        world_mark_current_room_clear();
        if ((rng_state & 3u) == 0u) {
            alloc_pickup(player.x, player.y, 1);
        }
    }

    if (!enemies_alive() && all_rooms_cleared() && key_state[KEY_CONFIRM]) {
        world_next_room();
    }
}

void trap_dispatch(u32 cause)
{
    if (cause == CAUSE_MEI) {
        u32 id = plic_claim();
        if (id == PLIC_ID_KEYBOARD) {
            input_handle_ps2_irq();
        }
        if (id) {
            plic_complete(id);
        }
    }
}

int main(void)
{
    csr_write_mtvec(0x80u);
    plic_enable(1u << PLIC_ID_KEYBOARD);
    csr_write_mie(MIE_MEIE);

    render_init();
    world_init();
    aim_x = 3;
    aim_y = 0;
    menu_choice = 0;
    menu_blink = 0;
    render_title();

    csr_write_mstatus(MSTATUS_MIE);

    while (1) {
        while ((VGA_STATUS & 1u) == 0u) {
        }
        VGA_STATUS = 1;
        input_poll();
        update_game();
        render_game();
    }
}
