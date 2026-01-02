// ============================================================
// engine.h
// ============================================================
#ifndef ENGINE_H_
#define ENGINE_H_

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

typedef enum EngineKey
{
    ENGINE_KEY_UNKNOWN = 0,

    ENGINE_KEY_W,
    ENGINE_KEY_A,
    ENGINE_KEY_S,
    ENGINE_KEY_D,

    ENGINE_KEY_UP,
    ENGINE_KEY_DOWN,
    ENGINE_KEY_LEFT,
    ENGINE_KEY_RIGHT,

    ENGINE_KEY_ESCAPE,
    ENGINE_KEY_ENTER,
    ENGINE_KEY_SPACE,

    ENGINE_KEY_COUNT
} EngineKey;

typedef struct EngineMouse
{
    int x;
    int y;
    bool left;
    bool right;
} EngineMouse;

typedef struct EngineInput
{
    bool keys_down[ENGINE_KEY_COUNT];     // current state
    bool keys_pressed[ENGINE_KEY_COUNT];  // went up->down this frame
    EngineMouse mouse;
} EngineInput;

typedef struct Game
{
    size_t fps;

    uint32_t *display;
    size_t display_width;
    size_t display_height;

    int16_t *audio;
    size_t audio_sample_rate;
    size_t audio_channels;

    EngineInput input;
} Game;

// NOTE Game lifecycle
Game game_init(void);

// dt_seconds: elapsed seconds since last update, provided by platform
void game_update(Game *game, float dt_seconds);

#endif // ENGINE_H_