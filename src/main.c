#include <conio.h>
#include <peekpoke.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define WORLD_X 32
#define WORLD_Y 8
#define WORLD_Z 32
#define SCREEN_W 30
#define SCREEN_H 16
#define INV_SLOTS 15
#define HOTBAR_SLOTS 5
#define MAX_HEALTH 8
#define RANDOM_TICKS_PER_FRAME 4
#define RAYCAST_MAX_LENGTH 0x40
#define PLAYER_HALF_WIDTH 5
#define PLAYER_CAM_HEIGHT 24
#define BLOCK_SIZE 16

#define SCREEN_RAM 0x0400
//#define COLOR_RAM 0xd800
#define BORDER_COLOR 0xd020
#define BG_COLOR 0xd021

#define SCR ((uint8_t*)SCREEN_RAM)
#define COL ((uint8_t*)COLOR_RAM)
#define SCREEN_SIZE 1000

static const uint16_t screen_row[25] = {
    0, 40, 80, 120, 160, 200, 240, 280, 320, 360,
    400, 440, 480, 520, 560, 600, 640, 680, 720, 760,
    800, 840, 880, 920, 960
};

enum BlockId {
    BLOCK_AIR = 0x0,
    BLOCK_GRASS = 0x1,
    BLOCK_DIRT = 0x2,
    BLOCK_STONE = 0x3,
    BLOCK_COBBLE = 0x4,
    BLOCK_LOG = 0x5,
    BLOCK_LEAVES = 0x6,
    BLOCK_PLANK = 0x7,
    BLOCK_COALORE = 0x8,
    BLOCK_IRONORE = 0x9,
    BLOCK_SAND = 0xA,
    BLOCK_GLASS = 0xB,
    BLOCK_SAPLING = 0xC,
    BLOCK_TABLE = 0xD,
    BLOCK_FURNACE = 0xE,
    BLOCK_CHEST = 0xF
};

enum ItemId {
    ITEM_AIR = 0x00,
    ITEM_STICK = 0x10,
    ITEM_DIRT = 0x20,
    ITEM_STONE = 0x30,
    ITEM_COBBLE = 0x40,
    ITEM_LOG = 0x50,
    ITEM_LEAVES = 0x60,
    ITEM_PLANK = 0x70,
    ITEM_COAL = 0x80,
    ITEM_IRONORE = 0x90,
    ITEM_SAND = 0xA0,
    ITEM_GLASS = 0xB0,
    ITEM_SAPLING = 0xC0,
    ITEM_IRONINGOT = 0xD0,
    ITEM_APPLE = 0xE0,
    ITEM_NONSTACKABLE = 0xF0,
    ITEM_WOODPICKAXE = 0xF0,
    ITEM_WOODAXE = 0xF1,
    ITEM_WOODSHOVEL = 0xF2,
    ITEM_WOODSWORD = 0xF3,
    ITEM_STONEPICKAXE = 0xF4,
    ITEM_STONEAXE = 0xF5,
    ITEM_STONESHOVEL = 0xF6,
    ITEM_STONESWORD = 0xF7,
    ITEM_IRONPICKAXE = 0xF8,
    ITEM_IRONAXE = 0xF9,
    ITEM_IRONSHOVEL = 0xFA,
    ITEM_IRONSWORD = 0xFB,
    ITEM_SHEARS = 0xFC,
    ITEM_TABLE = 0xFD,
    ITEM_FURNACE = 0xFE,
    ITEM_CHEST = 0xFF
};

enum ToolKind {
    TOOL_PICKAXE = 0,
    TOOL_AXE = 1,
    TOOL_SHOVEL = 2,
    TOOL_SWORD = 3
};

enum BlockType {
    BLOCKTYPE_STONE = 0,
    BLOCKTYPE_WOOD = 1,
    BLOCKTYPE_SOFT = 2,
    BLOCKTYPE_LEAVES = 3,
    BLOCKTYPE_GLASS = 4,
    BLOCKTYPE_SAPLING = 5
};

typedef struct RayHit {
    uint8_t hit;
    uint8_t block;
    uint8_t x;
    uint8_t y;
    uint8_t z;
    uint8_t prev_x;
    uint8_t prev_y;
    uint8_t prev_z;
    uint8_t dist;
} RayHit;

static uint8_t world[WORLD_Y][WORLD_Z][WORLD_X];
static uint8_t inventory[INV_SLOTS];
static uint8_t selected_slot;
static uint8_t player_x;
static uint8_t player_y;
static uint8_t player_z;
static uint8_t yaw;
static int8_t pitch;
static uint8_t health;
static uint8_t logs_in_world;
static uint8_t message_timer;
static char message[32];

static const int8_t sin16[16] = {
    0, 6, 11, 15, 16, 15, 11, 6,
    0, -6, -11, -15, -16, -15, -11, -6
};

static const int8_t cos16[16] = {
    16, 15, 11, 6, 0, -6, -11, -15,
    -16, -15, -11, -6, 0, 6, 11, 15
};

static const char item_name_initial[16] = {
    '.', 's', 'd', 'S', 'c', 'l', 'v', 'p',
    'o', 'i', 'a', 'g', 'n', 'I', '@', '*'
};

static void set_msg(const char *text)
{
    strncpy(message, text, sizeof(message) - 1);
    message[sizeof(message) - 1] = '\0';
    message_timer = 35;
}

static uint8_t rnd(uint8_t limit)
{
    if (limit == 0) {
        return 0;
    }
    return (uint8_t)(rand() % limit);
}

static uint8_t in_bounds(int8_t x, int8_t y, int8_t z)
{
    return x >= 0 && y >= 0 && z >= 0 &&
           x < WORLD_X && y < WORLD_Y && z < WORLD_Z;
}

static uint8_t get_block(int8_t x, int8_t y, int8_t z)
{
    if (!in_bounds(x, y, z)) {
        return BLOCK_STONE;
    }
    return world[(uint8_t)y][(uint8_t)z][(uint8_t)x];
}

static void set_block(int8_t x, int8_t y, int8_t z, uint8_t block)
{
    if (in_bounds(x, y, z)) {
        world[(uint8_t)y][(uint8_t)z][(uint8_t)x] = block;
    }
}

static uint8_t item_count(uint8_t item)
{
    if (item == ITEM_AIR) {
        return 0;
    }
    if (item >= ITEM_NONSTACKABLE) {
        return 1;
    }
    return item & 0x0f;
}

static uint8_t item_kind(uint8_t item)
{
    if (item >= ITEM_NONSTACKABLE) {
        return item;
    }
    return item & 0xf0;
}

static uint8_t block_to_item(uint8_t block)
{
    switch (block) {
        case BLOCK_GRASS:
        case BLOCK_DIRT:
            return ITEM_DIRT | 1;
        case BLOCK_STONE:
            return ITEM_COBBLE | 1;
        case BLOCK_LOG:
            return ITEM_LOG | 1;
        case BLOCK_LEAVES:
            return ITEM_LEAVES | 1;
        case BLOCK_PLANK:
            return ITEM_PLANK | 1;
        case BLOCK_COALORE:
            return ITEM_COAL | 1;
        case BLOCK_IRONORE:
            return ITEM_IRONORE | 1;
        case BLOCK_SAND:
            return ITEM_SAND | 1;
        case BLOCK_SAPLING:
            return ITEM_SAPLING | 1;
        case BLOCK_TABLE:
            return ITEM_TABLE;
        case BLOCK_FURNACE:
            return ITEM_FURNACE;
        case BLOCK_CHEST:
            return ITEM_CHEST;
    }
    return ITEM_AIR;
}

static uint8_t item_to_block(uint8_t item)
{
    if (item == ITEM_TABLE) {
        return BLOCK_TABLE;
    }
    if (item == ITEM_FURNACE) {
        return BLOCK_FURNACE;
    }
    if (item == ITEM_CHEST) {
        return BLOCK_CHEST;
    }
    if (item >= ITEM_NONSTACKABLE) {
        return BLOCK_AIR;
    }

    switch (item & 0xf0) {
        case ITEM_DIRT:
            return BLOCK_DIRT;
        case ITEM_STONE:
            return BLOCK_STONE;
        case ITEM_COBBLE:
            return BLOCK_COBBLE;
        case ITEM_LOG:
            return BLOCK_LOG;
        case ITEM_LEAVES:
            return BLOCK_LEAVES;
        case ITEM_PLANK:
            return BLOCK_PLANK;
        case ITEM_SAND:
            return BLOCK_SAND;
        case ITEM_GLASS:
            return BLOCK_GLASS;
        case ITEM_SAPLING:
            return BLOCK_SAPLING;
    }
    return BLOCK_AIR;
}

static uint8_t get_block_type(uint8_t block)
{
    switch (block) {
        case BLOCK_STONE:
        case BLOCK_COBBLE:
        case BLOCK_IRONORE:
        case BLOCK_COALORE:
        case BLOCK_FURNACE:
            return BLOCKTYPE_STONE;
        case BLOCK_PLANK:
        case BLOCK_LOG:
        case BLOCK_TABLE:
        case BLOCK_CHEST:
            return BLOCKTYPE_WOOD;
        case BLOCK_SAND:
        case BLOCK_DIRT:
        case BLOCK_GRASS:
            return BLOCKTYPE_SOFT;
        case BLOCK_LEAVES:
            return BLOCKTYPE_LEAVES;
        case BLOCK_GLASS:
            return BLOCKTYPE_GLASS;
    }
    return BLOCKTYPE_SAPLING;
}

static uint8_t get_block_hardness(uint8_t block)
{
    switch (block) {
        case BLOCK_LEAVES:
        case BLOCK_SAND:
        case BLOCK_DIRT:
        case BLOCK_GRASS:
        case BLOCK_SAPLING:
            return 0;
        case BLOCK_GLASS:
        case BLOCK_PLANK:
        case BLOCK_LOG:
        case BLOCK_TABLE:
        case BLOCK_CHEST:
            return 1;
        case BLOCK_STONE:
        case BLOCK_COBBLE:
        case BLOCK_COALORE:
        case BLOCK_FURNACE:
            return 2;
    }
    return 3;
}

static uint8_t tool_strength_for(uint8_t item, uint8_t block)
{
    uint8_t tool;
    uint8_t tier;
    uint8_t type;

    if (item < ITEM_NONSTACKABLE || item > ITEM_SHEARS) {
        return 4;
    }
    if (item == ITEM_SHEARS && block == BLOCK_LEAVES) {
        return 7;
    }

    tool = item & 0x03;
    tier = ((item >> 2) & 0x03) + 5;
    type = get_block_type(block);

    if ((tool == TOOL_PICKAXE && type == BLOCKTYPE_STONE) ||
        (tool == TOOL_AXE && type == BLOCKTYPE_WOOD) ||
        (tool == TOOL_SHOVEL && type == BLOCKTYPE_SOFT)) {
        return tier;
    }
    return 4;
}

static uint8_t add_item(uint8_t item)
{
    uint8_t i;
    uint8_t kind;
    uint8_t count;
    uint8_t sum;

    if (item == ITEM_AIR) {
        return 1;
    }

    kind = item_kind(item);
    count = item_count(item);

    if (item < ITEM_NONSTACKABLE) {
        for (i = 0; i < INV_SLOTS; ++i) {
            if (inventory[i] != ITEM_AIR && item_kind(inventory[i]) == kind) {
                sum = item_count(inventory[i]) + count;
                if (sum <= 15) {
                    inventory[i] = kind | sum;
                    return 1;
                }
                inventory[i] = kind | 15;
                count = sum - 15;
                item = kind | count;
            }
        }
    }

    for (i = 0; i < INV_SLOTS; ++i) {
        if (inventory[i] == ITEM_AIR) {
            inventory[i] = item;
            return 1;
        }
    }
    return 0;
}

static void remove_one_from_slot(uint8_t slot)
{
    uint8_t item;

    item = inventory[slot];
    if (item == ITEM_AIR) {
        return;
    }
    if (item >= ITEM_NONSTACKABLE) {
        inventory[slot] = ITEM_AIR;
        return;
    }
    if ((item & 0x0f) <= 1) {
        inventory[slot] = ITEM_AIR;
    } else {
        inventory[slot] = item - 1;
    }
}

static uint8_t can_walk(uint8_t block)
{
    return block == BLOCK_AIR || block == BLOCK_SAPLING || block == BLOCK_LEAVES;
}

static char block_char(uint8_t block, uint8_t dist)
{
    if (dist > 48) {
        return '.';
    }
    if (dist > 32) {
        return ':';
    }

    switch (block) {
        case BLOCK_GRASS:
            return 102;
        case BLOCK_DIRT:
            return ':';
        case BLOCK_STONE:
            return '#';
        case BLOCK_COBBLE:
            return '%';
        case BLOCK_LOG:
            return '|';
        case BLOCK_LEAVES:
            return '*';
        case BLOCK_PLANK:
            return '=';
        case BLOCK_COALORE:
            return '&';
        case BLOCK_IRONORE:
            return '+';
        case BLOCK_SAND:
            return '.';
        case BLOCK_GLASS:
            return 96;
        case BLOCK_SAPLING:
            return 'Y';
        case BLOCK_TABLE:
            return 'T';
        case BLOCK_FURNACE:
            return 'F';
        case BLOCK_CHEST:
            return 'C';
    }
    return ' ';
}

static uint8_t block_color(uint8_t block, uint8_t dist)
{
    if (dist > 48) {
        return COLOR_GRAY1;
    }
    switch (block) {
        case BLOCK_GRASS:
        case BLOCK_LEAVES:
        case BLOCK_SAPLING:
            return COLOR_GREEN;
        case BLOCK_DIRT:
        case BLOCK_LOG:
        case BLOCK_PLANK:
        case BLOCK_TABLE:
        case BLOCK_CHEST:
            return COLOR_BROWN;
        case BLOCK_STONE:
        case BLOCK_COBBLE:
        case BLOCK_FURNACE:
            return COLOR_GRAY2;
        case BLOCK_COALORE:
            return COLOR_GRAY1;
        case BLOCK_IRONORE:
            return COLOR_LIGHTRED;
        case BLOCK_SAND:
            return COLOR_YELLOW;
        case BLOCK_GLASS:
            return COLOR_CYAN;
    }
    return COLOR_BLACK;
}

static uint8_t screen_code(char ch)
{
    /* Convert a useful PETSCII/ASCII subset to C64 screen codes.
       Lowercase is intentionally folded to uppercase: this keeps direct
       screen RAM output readable without calling cc65's cputc converter. */
    if (ch >= 'a' && ch <= 'z') {
        return (uint8_t)(ch - 'a' + 1);
    }
    if (ch >= 'A' && ch <= 'Z') {
        return (uint8_t)(ch - 'A' + 1);
    }
    if (ch == 102) {              /* cc65/PETSCII checker used for grass */
        return 102;
    }
    return (uint8_t)ch;
}

static void __fastcall__ screen_put_at(uint8_t x, uint8_t y, char ch, uint8_t color)
{
    uint16_t pos = screen_row[y] + x;
    SCR[pos] = screen_code(ch);
    COL[pos] = color;
}

static void __fastcall__ screen_put_at_rev(uint8_t x, uint8_t y, char ch, uint8_t color)
{
    uint16_t pos = screen_row[y] + x;
    SCR[pos] = (uint8_t)(screen_code(ch) | 0x80);
    COL[pos] = color;
}

static void __fastcall__ screen_puts_at(uint8_t x, uint8_t y, const char *s, uint8_t color)
{
    uint16_t pos = screen_row[y] + x;
    while (*s && pos < SCREEN_SIZE) {
        SCR[pos] = screen_code(*s++);
        COL[pos] = color;
        ++pos;
    }
}

static void __fastcall__ screen_fill_at(uint8_t x, uint8_t y, uint8_t len, char ch, uint8_t color)
{
    uint16_t pos = screen_row[y] + x;
    uint8_t sc = screen_code(ch);
    while (len--) {
        SCR[pos] = sc;
        COL[pos] = color;
        ++pos;
    }
}

static void screen_clear(void)
{
    uint16_t i;
    for (i = 0; i < SCREEN_SIZE; ++i) {
        SCR[i] = 32;
        COL[i] = COLOR_WHITE;
    }
}

static void put_colored(uint8_t x, uint8_t y, char ch, uint8_t color)
{
    screen_put_at(x, y, ch, color);
}

static void raycast(uint8_t angle, int8_t ray_pitch, RayHit *hit)
{
    int16_t rx;
    int16_t ry;
    int16_t rz;
    int16_t dx;
    int16_t dy;
    int16_t dz;
    uint8_t dist;
    int8_t bx;
    int8_t by;
    int8_t bz;

    rx = (int16_t)player_x + PLAYER_HALF_WIDTH;
    ry = (int16_t)player_y + PLAYER_CAM_HEIGHT;
    rz = (int16_t)player_z + PLAYER_HALF_WIDTH;

    dx = sin16[angle & 0x0f];
    dz = cos16[angle & 0x0f];
    dy = ray_pitch;

    hit->hit = 0;
    hit->block = BLOCK_AIR;
    hit->x = (uint8_t)(rx >> 4);
    hit->y = (uint8_t)(ry >> 4);
    hit->z = (uint8_t)(rz >> 4);
    hit->prev_x = hit->x;
    hit->prev_y = hit->y;
    hit->prev_z = hit->z;
    hit->dist = RAYCAST_MAX_LENGTH;

    for (dist = 1; dist <= RAYCAST_MAX_LENGTH; ++dist) {
        rx += dx;
        ry += dy;
        rz += dz;

        bx = (int8_t)(rx >> 4);
        by = (int8_t)(ry >> 4);
        bz = (int8_t)(rz >> 4);

        if (!in_bounds(bx, by, bz)) {
            hit->hit = 1;
            hit->block = BLOCK_STONE;
            hit->x = (uint8_t)bx;
            hit->y = (uint8_t)by;
            hit->z = (uint8_t)bz;
            hit->dist = dist;
            return;
        }

        hit->prev_x = hit->x;
        hit->prev_y = hit->y;
        hit->prev_z = hit->z;
        hit->x = (uint8_t)bx;
        hit->y = (uint8_t)by;
        hit->z = (uint8_t)bz;
        hit->block = get_block(bx, by, bz);

        if (hit->block != BLOCK_AIR) {
            hit->hit = 1;
            hit->dist = dist;
            return;
        }
    }
}

static void draw_world(void)
{
    uint8_t sx;
    uint8_t sy;
    uint8_t angle;
    int8_t ray_pitch;
    RayHit hit;

    for (sy = 0; sy < SCREEN_H; ++sy) {
        for (sx = 0; sx < SCREEN_W; ++sx) {
            angle = (uint8_t)(yaw + ((int8_t)sx - (SCREEN_W / 2)) / 4);
            ray_pitch = (int8_t)(((SCREEN_H / 2) - (int8_t)sy) + pitch);
            raycast(angle, ray_pitch, &hit);
            if (hit.hit) {
                put_colored(sx, sy, block_char(hit.block, hit.dist),
                            block_color(hit.block, hit.dist));
            } else if (sy < SCREEN_H / 2) {
                put_colored(sx, sy, ' ', COLOR_LIGHTBLUE);
            } else {
                put_colored(sx, sy, '.', COLOR_GRAY1);
            }
        }
    }

    screen_put_at_rev(SCREEN_W / 2, SCREEN_H / 2, '+', COLOR_WHITE);
}

static void draw_item_line(uint8_t row, uint8_t slot, uint8_t item, uint8_t selected)
{
    uint16_t pos = screen_row[row] + 31;
    uint8_t rev = selected ? 0x80 : 0;
    uint8_t count = item_count(item);

    SCR[pos]     = (uint8_t)(screen_code((char)('1' + slot)) | rev);
    SCR[pos + 1] = (uint8_t)(screen_code(':') | rev);
    SCR[pos + 2] = (uint8_t)(screen_code(item_name_initial[item >> 4]) | rev);
    SCR[pos + 3] = (uint8_t)(screen_code((char)('0' + (count / 10))) | rev);
    SCR[pos + 4] = (uint8_t)(screen_code((char)('0' + (count % 10))) | rev);

    COL[pos] = COL[pos + 1] = COL[pos + 2] = COL[pos + 3] = COL[pos + 4] = COLOR_WHITE;
}

static void draw_hud(void)
{
    uint8_t i;
    uint8_t item;

    screen_puts_at(31, 0, "HP", COLOR_WHITE);
    for (i = 0; i < MAX_HEALTH; ++i) {
        screen_put_at((uint8_t)(31 + i), 1, i < health ? 83 : '.', COLOR_WHITE);
    }

    screen_puts_at(31, 3, "HOTBAR", COLOR_WHITE);
    for (i = 0; i < HOTBAR_SLOTS; ++i) {
        item = inventory[i];
        draw_item_line((uint8_t)(4 + i), i, item, i == selected_slot);
    }

    screen_puts_at(31, 11, "W/S", COLOR_WHITE);
    screen_puts_at(31, 12, "A/D", COLOR_WHITE);
    screen_puts_at(31, 13, "I/K", COLOR_WHITE);
    screen_puts_at(31, 14, "SPC", COLOR_WHITE);

    screen_fill_at(0, 22, 40, ' ', COLOR_LIGHTBLUE);
    if (message_timer) {
        screen_puts_at(0, 22, message, COLOR_LIGHTBLUE);
        --message_timer;
    }
}

static void render(void)
{
    draw_world();
    draw_hud();
}

static void generate_tree(uint8_t x, uint8_t y, uint8_t z)
{
    int8_t dx;
    int8_t dz;
    uint8_t i;

    for (i = 0; i < 4; ++i) {
        if (y + i < WORLD_Y) {
            set_block((int8_t)x, (int8_t)(y + i), (int8_t)z, BLOCK_LOG);
            ++logs_in_world;
        }
    }

    for (dx = -2; dx <= 2; ++dx) {
        for (dz = -2; dz <= 2; ++dz) {
            if (abs(dx) + abs(dz) < 4) {
                set_block((int8_t)x + dx, (int8_t)y + 4, (int8_t)z + dz, BLOCK_LEAVES);
                set_block((int8_t)x + dx, (int8_t)y + 5, (int8_t)z + dz, BLOCK_LEAVES);
            }
        }
    }
}

static uint8_t has_adjacent_grass(uint8_t x, uint8_t y, uint8_t z)
{
    int8_t dx;
    int8_t dz;

    for (dx = -1; dx <= 1; ++dx) {
        for (dz = -1; dz <= 1; ++dz) {
            if (get_block((int8_t)x + dx, (int8_t)y, (int8_t)z + dz) == BLOCK_GRASS) {
                return 1;
            }
        }
    }
    return 0;
}

static void random_tick(void)
{
    uint8_t i;
    uint8_t x;
    uint8_t y;
    uint8_t z;
    uint8_t b;

    for (i = 0; i < RANDOM_TICKS_PER_FRAME; ++i) {
        x = rnd(WORLD_X);
        y = rnd(WORLD_Y);
        z = rnd(WORLD_Z);
        b = world[y][z][x];

        if (b == BLOCK_DIRT && y + 1 < WORLD_Y &&
            world[y + 1][z][x] == BLOCK_AIR && has_adjacent_grass(x, y, z)) {
            world[y][z][x] = BLOCK_GRASS;
        } else if (b == BLOCK_GRASS && y + 1 < WORLD_Y &&
                   world[y + 1][z][x] != BLOCK_AIR) {
            world[y][z][x] = BLOCK_DIRT;
        } else if (b == BLOCK_LEAVES && logs_in_world == 0 && rnd(5) == 0) {
            world[y][z][x] = BLOCK_AIR;
            if (rnd(100) < 20) {
                add_item(ITEM_STICK | 1);
            } else if (rnd(100) < 12) {
                add_item(ITEM_SAPLING | 1);
            } else if (rnd(100) < 6) {
                add_item(ITEM_APPLE | 1);
            }
        } else if (b == BLOCK_SAPLING && rnd(24) == 0) {
            world[y][z][x] = BLOCK_AIR;
            generate_tree(x, y, z);
            set_msg("sapling grew");
        }
    }
}

static void init_world(void)
{
    uint8_t x;
    uint8_t y;
    uint8_t z;

    memset(world, BLOCK_AIR, sizeof(world));
    logs_in_world = 0;

    for (z = 0; z < WORLD_Z; ++z) {
        for (x = 0; x < WORLD_X; ++x) {
            world[0][z][x] = BLOCK_STONE;
            world[1][z][x] = BLOCK_DIRT;
            world[2][z][x] = BLOCK_GRASS;
        }
    }

    for (y = 2; y < 5; ++y) {
        world[y][4][4] = BLOCK_STONE;
        world[y][4][5] = BLOCK_COALORE;
        world[y][8][11] = BLOCK_IRONORE;
    }

    generate_tree(11, 3, 5);
    generate_tree(5, 3, 11);
    world[3][8][8] = BLOCK_TABLE;
    world[3][8][9] = BLOCK_FURNACE;
    world[3][8][10] = BLOCK_CHEST;
    world[3][10][8] = BLOCK_SAPLING;
    world[3][10][9] = BLOCK_SAND;
}

static void init_player(void)
{
    memset(inventory, 0, sizeof(inventory));
    inventory[0] = ITEM_DIRT | 4;
    inventory[1] = ITEM_LOG | 5;
    inventory[2] = ITEM_COAL | 9;
    inventory[3] = ITEM_FURNACE;
    inventory[4] = ITEM_TABLE;

    selected_slot = 0;
    player_x = 8 * BLOCK_SIZE;
    player_y = 3 * BLOCK_SIZE;
    player_z = 6 * BLOCK_SIZE;
    yaw = 0;
    pitch = 0;
    health = MAX_HEALTH;
    set_msg("3d petscii raycast");
}

static void try_move(int8_t forward, int8_t strafe)
{
    int16_t nx;
    int16_t nz;
    int8_t block_x;
    int8_t block_y;
    int8_t block_z;
    int8_t dx;
    int8_t dz;

    dx = (int8_t)((cos16[yaw & 0x0f] * strafe - sin16[yaw & 0x0f] * forward) >> 3);
    dz = (int8_t)((sin16[yaw & 0x0f] * strafe + cos16[yaw & 0x0f] * forward) >> 3);
    nx = (int16_t)player_x + dx;
    nz = (int16_t)player_z + dz;

    block_x = (int8_t)((nx + PLAYER_HALF_WIDTH) >> 4);
    block_y = (int8_t)(player_y >> 4);
    block_z = (int8_t)((nz + PLAYER_HALF_WIDTH) >> 4);

    if (in_bounds(block_x, block_y, block_z) &&
        can_walk(get_block(block_x, block_y, block_z)) &&
        can_walk(get_block(block_x, (int8_t)(block_y + 1), block_z))) {
        player_x = (uint8_t)nx;
        player_z = (uint8_t)nz;
    }
}

static uint8_t center_ray(RayHit *hit)
{
    raycast(yaw, pitch, hit);
    return hit->hit && hit->dist <= RAYCAST_MAX_LENGTH;
}

static void break_target(void)
{
    RayHit hit;
    uint8_t held;
    uint8_t strength;
    uint8_t hardness;
    uint8_t drop;

    if (!center_ray(&hit) || hit.block == BLOCK_AIR ||
        (hit.block == BLOCK_STONE &&
         !in_bounds((int8_t)hit.x, (int8_t)hit.y, (int8_t)hit.z))) {
        return;
    }

    held = inventory[selected_slot];
    strength = tool_strength_for(held, hit.block);
    hardness = get_block_hardness(hit.block);
    if (strength <= hardness) {
        set_msg("tool too weak");
        return;
    }

    if (hit.block == BLOCK_LOG && logs_in_world) {
        --logs_in_world;
    }

    drop = block_to_item(hit.block);
    if (hit.block == BLOCK_GLASS) {
        drop = ITEM_AIR;
    }
    if (hit.block == BLOCK_LEAVES && held != ITEM_SHEARS) {
        drop = ITEM_AIR;
        if (rnd(100) < 20) {
            drop = ITEM_SAPLING | 1;
        } else if (rnd(100) < 28) {
            drop = ITEM_STICK | 1;
        } else if (rnd(100) < 35) {
            drop = ITEM_APPLE | 1;
        }
    }

    set_block((int8_t)hit.x, (int8_t)hit.y, (int8_t)hit.z, BLOCK_AIR);
    if (drop != ITEM_AIR && !add_item(drop)) {
        set_msg("inventory full");
    } else {
        set_msg("block broken");
    }
}

static void place_target(void)
{
    RayHit hit;
    uint8_t item;
    uint8_t block;

    if (!center_ray(&hit)) {
        return;
    }
    if (!in_bounds((int8_t)hit.prev_x, (int8_t)hit.prev_y, (int8_t)hit.prev_z)) {
        return;
    }

    item = inventory[selected_slot];
    block = item_to_block(item);
    if (block == BLOCK_AIR) {
        set_msg("not placeable");
        return;
    }

    if (get_block((int8_t)hit.prev_x, (int8_t)hit.prev_y, (int8_t)hit.prev_z) != BLOCK_AIR) {
        return;
    }
    if (block == BLOCK_SAPLING &&
        get_block((int8_t)hit.prev_x, (int8_t)(hit.prev_y - 1), (int8_t)hit.prev_z) != BLOCK_DIRT &&
        get_block((int8_t)hit.prev_x, (int8_t)(hit.prev_y - 1), (int8_t)hit.prev_z) != BLOCK_GRASS) {
        set_msg("needs dirt");
        return;
    }

    set_block((int8_t)hit.prev_x, (int8_t)hit.prev_y, (int8_t)hit.prev_z, block);
    if (block == BLOCK_LOG) {
        ++logs_in_world;
    }
    remove_one_from_slot(selected_slot);
    set_msg("block placed");
}

static void eat_selected(void)
{
    uint8_t item;

    item = inventory[selected_slot];
    if ((item & 0xf0) != ITEM_APPLE) {
        return;
    }
    if (health < MAX_HEALTH) {
        health += 2;
        if (health > MAX_HEALTH) {
            health = MAX_HEALTH;
        }
        remove_one_from_slot(selected_slot);
        set_msg("ate apple");
    }
}

static void handle_key(char key)
{
    switch (key) {
        case 'w':
        case 'W':
            try_move(1, 0);
            break;
        case 's':
        case 'S':
            try_move(-1, 0);
            break;
        case 'a':
        case 'A':
            yaw = (uint8_t)((yaw - 1) & 0x0f);
            break;
        case 'd':
        case 'D':
            yaw = (uint8_t)((yaw + 1) & 0x0f);
            break;
        case 'j':
        case 'J':
            try_move(0, -1);
            break;
        case 'l':
        case 'L':
            try_move(0, 1);
            break;
        case 'i':
        case 'I':
            if (pitch < 5) {
                ++pitch;
            }
            break;
        case 'k':
        case 'K':
            if (pitch > -5) {
                --pitch;
            }
            break;
        case ' ':
            break_target();
            break;
        case '\r':
            place_target();
            break;
        case 'e':
        case 'E':
            eat_selected();
            break;
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
            selected_slot = (uint8_t)(key - '1');
            break;
    }
}

static void setup_c64(void)
{
    POKE(BORDER_COLOR, COLOR_BLACK);
    POKE(BG_COLOR, COLOR_BLACK);
    cursor(0);
    screen_clear();
}

int main(void)
{
    char key;
    uint8_t running;

    setup_c64();
    srand((unsigned)PEEK(0xa2));
    init_world();
    init_player();

    running = 1;
    while (running) {
        render();
        random_tick();

        if (kbhit()) {
            key = cgetc();
            if (key == 'q' || key == 'Q') {
                running = 0;
            } else {
                handle_key(key);
            }
        }
    }

    screen_clear();
    cursor(1);
    screen_puts_at(0, 0, "MINECRAFT C64 STOPPED", COLOR_WHITE);
    return 0;
}
