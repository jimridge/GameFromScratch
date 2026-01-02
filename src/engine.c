// ============================================================
// engine.c
// ============================================================
#include "engine.h"

#include <string.h>
#include <math.h>

// ---- Engine-chosen defaults (platform reads these from game_init)
#define FPS 60
#define DISPLAY_WIDTH  960
#define DISPLAY_HEIGHT 540

static uint32_t display[DISPLAY_WIDTH * DISPLAY_HEIGHT];

#define AUDIO_SAMPLE_RATE 44100
#define AUDIO_CHANNELS 2
#if __STDC_VERSION__ >= 201112L
_Static_assert(AUDIO_SAMPLE_RATE % FPS == 0, "Sample rate must be divisible by FPS");
#endif
#define AUDIO_CAPACITY (AUDIO_SAMPLE_RATE/FPS*AUDIO_CHANNELS)
static int16_t audio[AUDIO_CAPACITY];


// NOTE Game defaults
#define PLAYER_SPEED 64.0f // NOTE Pixels per second px / s

// Display is BGRA in memory (platform blits as BGRA little-endian)
static inline uint32_t
pack_bgra(uint8_t r, uint8_t g, uint8_t b)
{
    uint8_t B = b, G = g, R = r, A = 255;
    return (uint32_t)(B | (G << 8) | (R << 16) | (A << 24));
}

static void
clear_screen(Game *game, uint8_t r, uint8_t g, uint8_t b)
{
    uint32_t p = pack_bgra(r, g, b);
    size_t count = game->display_width * game->display_height;
    for (size_t i = 0; i < count; ++i) game->display[i] = p;
}

static void
draw_rect(Game *game, int x, int y, int w, int h, uint8_t r, uint8_t g, uint8_t b)
{
    if (w <= 0 || h <= 0) return;

    int maxW = (int)game->display_width;
    int maxH = (int)game->display_height;

    int x0 = x;
    int y0 = y;
    int x1 = x + w;
    int y1 = y + h;

    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > maxW) x1 = maxW;
    if (y1 > maxH) y1 = maxH;

    if (x0 >= x1 || y0 >= y1) return;

    uint32_t p = pack_bgra(r, g, b);

    for (int yy = y0; yy < y1; ++yy)
    {
        uint32_t *row = game->display + (size_t)yy * (size_t)game->display_width;
        for (int xx = x0; xx < x1; ++xx)
        {
            row[xx] = p;
        }
    }
}

Game
game_init(void)
{
    Game g;
    memset(&g, 0, sizeof(g));

    g.fps = FPS;

    g.display = display;
    g.display_width  = DISPLAY_WIDTH;
    g.display_height = DISPLAY_HEIGHT;

    g.audio = audio;
    g.audio_sample_rate = AUDIO_SAMPLE_RATE;
    g.audio_channels = AUDIO_CHANNELS;

    return g;
}

void
game_update(Game *game, float dt_seconds)
{
    // dt sanity clamp (prevents giant jumps when pausing in debugger)
    if (dt_seconds < 0.0f) dt_seconds = 0.0f;
    if (dt_seconds > 0.25f) dt_seconds = 0.25f;

    // Clear one-frame pressed flags at the START of update.
    // Platform sets keys_pressed on keyDown; we consume it for one frame.
    for (int i = 0; i < ENGINE_KEY_COUNT; ++i)
    {
        game->input.keys_pressed[i] = false;
    }

    // ---- Player state (kept internal to engine)
    static float player_x = -1.0f;
    static float player_y = -1.0f;

    const int rect_w = 32;
    const int rect_h = 32;

    // First frame: centre it
    if (player_x < 0.0f && player_y < 0.0f)
    {
        player_x = (float)((int)game->display_width  / 2 - rect_w / 2);
        player_y = (float)((int)game->display_height / 2 - rect_h / 2);
    }

    // Movement in pixels/sec (FPS-independent)
    const float speed = PLAYER_SPEED; // px/s

    float vx = 0.0f;
    float vy = 0.0f;

    if (game->input.keys_down[ENGINE_KEY_A]) vx -= 1.0f;
    if (game->input.keys_down[ENGINE_KEY_D]) vx += 1.0f;
    if (game->input.keys_down[ENGINE_KEY_W]) vy += 1.0f;
    if (game->input.keys_down[ENGINE_KEY_S]) vy -= 1.0f;

    // Normalize diagonal so it isn't faster
    float len = sqrtf(vx*vx + vy*vy);
    if (len > 0.0f)
    {
        vx /= len;
        vy /= len;
    }

    player_x += vx * speed * dt_seconds;
    player_y += vy * speed * dt_seconds;

    // Clamp to screen
    float max_x = (float)((int)game->display_width  - rect_w);
    float max_y = (float)((int)game->display_height - rect_h);
    if (player_x < 0.0f) player_x = 0.0f;
    if (player_y < 0.0f) player_y = 0.0f;
    if (player_x > max_x) player_x = max_x;
    if (player_y > max_y) player_y = max_y;

    // ---- Render
    clear_screen(game, 20, 20, 30); // dark background
    draw_rect(game, (int)player_x, (int)player_y, rect_w, rect_h, 255, 0, 255);
}