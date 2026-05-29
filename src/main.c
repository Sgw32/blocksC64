#include <conio.h>
#include <peekpoke.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define WORLD_W 32
#define WORLD_H 16
#define VIEW_W 30
#define VIEW_H 16
#define INV_SLOTS 15
#define HOTBAR_SLOTS 5
#define MAX_HEALTH 8
#define RANDOM_TICKS_PER_FRAME 3

//#define COLOR_RAM 0xd800
#define BORDER_COLOR 0xd020
#define BG_COLOR 0xd021

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

static uint8_t world[WORLD_H][WORLD_W];
static uint8_t inventory[INV_SLOTS];
static uint8_t selected_slot;
static uint8_t player_x;
static uint8_t player_y;
static int8_t target_dx;
static int8_t target_dy;
static uint8_t health;
static uint8_t logs_in_world;
static uint8_t message_timer;
static char message[32];

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

static uint8_t in_bounds(int8_t x, int8_t y)
{
    return x >= 0 && y >= 0 && x < WORLD_W && y < WORLD_H;
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
        case BLOCK_GLASS:
            return ITEM_AIR;
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
    if (item >= ITEM_TABLE) {
        if (item == ITEM_TABLE) {
            return BLOCK_TABLE;
        }
        if (item == ITEM_FURNACE) {
            return BLOCK_FURNACE;
        }
        if (item == ITEM_CHEST) {
            return BLOCK_CHEST;
        }
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

    if (item < ITEM_NONSTACKABLE || item > 0xfc) {
        return 4;
    }
    if (item == 0xfc && block == BLOCK_LEAVES) {
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
            if (item_kind(inventory[i]) == kind && inventory[i] != ITEM_AIR) {
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

static char block_char(uint8_t block)
{
    switch (block) {
        case BLOCK_AIR:
            return ' ';
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
    return '?';
}

static uint8_t block_color(uint8_t block)
{
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

static void put_colored(uint8_t x, uint8_t y, char ch, uint8_t color)
{
    gotoxy(x, y);
    textcolor(color);
    cputc(ch);
}

static void draw_world(void)
{
    uint8_t x;
    uint8_t y;
    int8_t wx;
    int8_t wy;
    int8_t sx;
    int8_t sy;

    sx = (int8_t)player_x - VIEW_W / 2;
    sy = (int8_t)player_y - VIEW_H / 2;

    for (y = 0; y < VIEW_H; ++y) {
        for (x = 0; x < VIEW_W; ++x) {
            wx = sx + x;
            wy = sy + y;
            if (!in_bounds(wx, wy)) {
                put_colored(x, y, ' ', COLOR_BLACK);
            } else {
                put_colored(x, y, block_char(world[(uint8_t)wy][(uint8_t)wx]),
                            block_color(world[(uint8_t)wy][(uint8_t)wx]));
            }
        }
    }

    put_colored(VIEW_W / 2, VIEW_H / 2, '@', COLOR_WHITE);

    wx = (int8_t)player_x + target_dx;
    wy = (int8_t)player_y + target_dy;
    if (in_bounds(wx, wy)) {
        x = (uint8_t)(wx - sx);
        y = (uint8_t)(wy - sy);
        if (x < VIEW_W && y < VIEW_H) {
            revers(1);
            put_colored(x, y, block_char(world[(uint8_t)wy][(uint8_t)wx]), COLOR_WHITE);
            revers(0);
        }
    }
}

static void draw_hud(void)
{
    uint8_t i;
    uint8_t item;

    textcolor(COLOR_WHITE);
    gotoxy(31, 0);
    cputs("HP");
    gotoxy(31, 1);
    for (i = 0; i < MAX_HEALTH; ++i) {
        cputc(i < health ? 83 : 46);
    }

    gotoxy(31, 3);
    cputs("HOTBAR");
    for (i = 0; i < HOTBAR_SLOTS; ++i) {
        gotoxy(31, (uint8_t)(4 + i));
        item = inventory[i];
        revers(i == selected_slot);
        cprintf("%u:%c%02u", i + 1, item_name_initial[item >> 4], item_count(item));
        revers(0);
    }

    gotoxy(31, 11);
    cputs("WASD");
    gotoxy(31, 12);
    cputs("IJKL");
    gotoxy(31, 13);
    cputs("SPC");
    gotoxy(31, 14);
    cputs("RET");

    gotoxy(0, 22);
    textcolor(COLOR_LIGHTBLUE);
    cclear(40);
    gotoxy(0, 22);
    if (message_timer) {
        cputs(message);
        --message_timer;
    }
}

static void render(void)
{
    draw_world();
    draw_hud();
}

static void generate_tree(uint8_t x, uint8_t y)
{
    int8_t dx;
    int8_t dy;
    uint8_t height;
    uint8_t ly;

    height = 3 + rnd(2);
    if (y < height) {
        return;
    }

    for (ly = 0; ly < height; ++ly) {
        if (world[y - ly][x] == BLOCK_AIR || world[y - ly][x] == BLOCK_SAPLING) {
            world[y - ly][x] = BLOCK_LOG;
            ++logs_in_world;
        }
    }

    for (dy = -2; dy <= 1; ++dy) {
        for (dx = -2; dx <= 2; ++dx) {
            if (abs(dx) + abs(dy) < 4 &&
                in_bounds((int8_t)x + dx, (int8_t)y - (int8_t)height + dy)) {
                if (world[y - height + dy][x + dx] == BLOCK_AIR) {
                    world[y - height + dy][x + dx] = BLOCK_LEAVES;
                }
            }
        }
    }
}

static uint8_t has_adjacent_grass(uint8_t x, uint8_t y)
{
    int8_t dx;
    int8_t dy;

    for (dy = -1; dy <= 1; ++dy) {
        for (dx = -1; dx <= 1; ++dx) {
            if (in_bounds((int8_t)x + dx, (int8_t)y + dy) &&
                world[y + dy][x + dx] == BLOCK_GRASS) {
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
    uint8_t b;

    for (i = 0; i < RANDOM_TICKS_PER_FRAME; ++i) {
        x = rnd(WORLD_W);
        y = rnd(WORLD_H);
        b = world[y][x];

        if (b == BLOCK_DIRT && has_adjacent_grass(x, y) && rnd(4) == 0) {
            world[y][x] = BLOCK_GRASS;
        } else if (b == BLOCK_GRASS && y > 0 && world[y - 1][x] != BLOCK_AIR) {
            world[y][x] = BLOCK_DIRT;
        } else if (b == BLOCK_LEAVES && logs_in_world == 0 && rnd(5) == 0) {
            world[y][x] = BLOCK_AIR;
            if (rnd(100) < 20) {
                add_item(ITEM_STICK | 1);
            } else if (rnd(100) < 12) {
                add_item(ITEM_SAPLING | 1);
            } else if (rnd(100) < 6) {
                add_item(ITEM_APPLE | 1);
            }
        } else if (b == BLOCK_SAPLING && rnd(24) == 0) {
            world[y][x] = BLOCK_AIR;
            generate_tree(x, y);
            set_msg("sapling grew");
        }
    }
}

static void init_world(void)
{
    uint8_t x;
    uint8_t y;

    memset(world, BLOCK_AIR, sizeof(world));
    logs_in_world = 0;

    for (y = 10; y < WORLD_H; ++y) {
        for (x = 0; x < WORLD_W; ++x) {
            world[y][x] = (y == 10) ? BLOCK_GRASS : BLOCK_DIRT;
        }
    }

    for (x = 3; x < 9; ++x) {
        world[12][x] = BLOCK_STONE;
    }
    world[11][6] = BLOCK_COALORE;
    world[11][7] = BLOCK_IRONORE;

    generate_tree(20, 10);
    generate_tree(25, 10);

    world[10][13] = BLOCK_SAND;
    world[9][14] = BLOCK_SAPLING;
    world[10][16] = BLOCK_TABLE;
    world[10][17] = BLOCK_FURNACE;
    world[10][18] = BLOCK_CHEST;
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
    player_x = 15;
    player_y = 9;
    target_dx = 0;
    target_dy = 1;
    health = MAX_HEALTH;
    set_msg("minecraft c64");
}

static uint8_t can_walk(uint8_t block)
{
    return block == BLOCK_AIR || block == BLOCK_SAPLING || block == BLOCK_LEAVES;
}

static void try_move(int8_t dx, int8_t dy)
{
    int8_t nx;
    int8_t ny;

    nx = (int8_t)player_x + dx;
    ny = (int8_t)player_y + dy;
    target_dx = dx;
    target_dy = dy;

    if (dx == 0 && dy == 0) {
        return;
    }
    if (in_bounds(nx, ny) && can_walk(world[(uint8_t)ny][(uint8_t)nx])) {
        player_x = (uint8_t)nx;
        player_y = (uint8_t)ny;
    }
}

static void set_target(int8_t dx, int8_t dy)
{
    target_dx = dx;
    target_dy = dy;
}

static void break_target(void)
{
    int8_t tx;
    int8_t ty;
    uint8_t block;
    uint8_t held;
    uint8_t strength;
    uint8_t hardness;
    uint8_t drop;

    tx = (int8_t)player_x + target_dx;
    ty = (int8_t)player_y + target_dy;
    if (!in_bounds(tx, ty)) {
        return;
    }

    block = world[(uint8_t)ty][(uint8_t)tx];
    if (block == BLOCK_AIR) {
        return;
    }

    held = inventory[selected_slot];
    strength = tool_strength_for(held, block);
    hardness = get_block_hardness(block);
    if (strength <= hardness) {
        set_msg("tool too weak");
        return;
    }

    if (block == BLOCK_LOG && logs_in_world) {
        --logs_in_world;
    }

    drop = block_to_item(block);
    if (block == BLOCK_LEAVES && held != 0xfc) {
        drop = ITEM_AIR;
        if (rnd(100) < 20) {
            drop = ITEM_SAPLING | 1;
        } else if (rnd(100) < 28) {
            drop = ITEM_STICK | 1;
        } else if (rnd(100) < 35) {
            drop = ITEM_APPLE | 1;
        }
    }

    world[(uint8_t)ty][(uint8_t)tx] = BLOCK_AIR;
    if (drop != ITEM_AIR) {
        if (!add_item(drop)) {
            set_msg("inventory full");
        } else {
            set_msg("block broken");
        }
    } else {
        set_msg("block broken");
    }
}

static void place_target(void)
{
    int8_t tx;
    int8_t ty;
    uint8_t item;
    uint8_t block;

    tx = (int8_t)player_x + target_dx;
    ty = (int8_t)player_y + target_dy;
    if (!in_bounds(tx, ty)) {
        return;
    }
    if (world[(uint8_t)ty][(uint8_t)tx] != BLOCK_AIR &&
        world[(uint8_t)ty][(uint8_t)tx] != BLOCK_LEAVES) {
        return;
    }

    item = inventory[selected_slot];
    block = item_to_block(item);
    if (block == BLOCK_AIR) {
        set_msg("not placeable");
        return;
    }
    if (block == BLOCK_SAPLING) {
        if ((uint8_t)ty + 1 >= WORLD_H ||
            (world[(uint8_t)ty + 1][(uint8_t)tx] != BLOCK_DIRT &&
             world[(uint8_t)ty + 1][(uint8_t)tx] != BLOCK_GRASS)) {
            set_msg("needs dirt");
            return;
        }
    }

    world[(uint8_t)ty][(uint8_t)tx] = block;
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
            try_move(0, -1);
            break;
        case 's':
        case 'S':
            try_move(0, 1);
            break;
        case 'a':
        case 'A':
            try_move(-1, 0);
            break;
        case 'd':
        case 'D':
            try_move(1, 0);
            break;
        case 'i':
        case 'I':
            set_target(0, -1);
            break;
        case 'k':
        case 'K':
            set_target(0, 1);
            break;
        case 'j':
        case 'J':
            set_target(-1, 0);
            break;
        case 'l':
        case 'L':
            set_target(1, 0);
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
    uint16_t i;

    POKE(BORDER_COLOR, COLOR_BLACK);
    POKE(BG_COLOR, COLOR_BLACK);
    clrscr();
    cursor(0);
    for (i = 0; i < 1000; ++i) {
        POKE(COLOR_RAM + i, COLOR_WHITE);
    }
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

    clrscr();
    cursor(1);
    textcolor(COLOR_WHITE);
    cputs("minecraft c64 stopped\r\n");
    return 0;
}
