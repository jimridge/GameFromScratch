#import <Cocoa/Cocoa.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>

#include "engine.h"

// ============================================================
// Timing helpers
// ============================================================
static double GetTimeSeconds(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

// ============================================================
// Software backbuffer (platform-owned, blitted with CoreGraphics)
// ============================================================
typedef struct Backbuffer {
    int width;
    int height;
    int bytesPerPixel;   // 4
    int pitch;           // bytes per row
    void *memory;        // BGRA 8:8:8:8
} Backbuffer;

static Backbuffer gBackbuffer = {0};
static double GlobalFPS = 0.0;

static void ResizeBackbuffer(int width, int height)
{
    if (width < 1)  width = 1;
    if (height < 1) height = 1;

    gBackbuffer.width = width;
    gBackbuffer.height = height;
    gBackbuffer.bytesPerPixel = 4;
    gBackbuffer.pitch = width * gBackbuffer.bytesPerPixel;

    size_t size = (size_t)gBackbuffer.pitch * (size_t)height;

    if (gBackbuffer.memory) free(gBackbuffer.memory);
    gBackbuffer.memory = malloc(size);
    memset(gBackbuffer.memory, 0, size);
}

// ============================================================
// Input mapping (macOS keyCode -> EngineKey)
// ============================================================
static EngineKey MapKey(unsigned short keyCode)
{
    // Common macOS virtual key codes:
    // W 0x0D, A 0x00, S 0x01, D 0x02
    // Arrow keys: Up 0x7E, Down 0x7D, Left 0x7B, Right 0x7C
    // Escape 0x35, Return 0x24, Space 0x31
    switch (keyCode)
    {
        case 0x0D: return ENGINE_KEY_W;
        case 0x00: return ENGINE_KEY_A;
        case 0x01: return ENGINE_KEY_S;
        case 0x02: return ENGINE_KEY_D;

        case 0x7E: return ENGINE_KEY_UP;
        case 0x7D: return ENGINE_KEY_DOWN;
        case 0x7B: return ENGINE_KEY_LEFT;
        case 0x7C: return ENGINE_KEY_RIGHT;

        case 0x35: return ENGINE_KEY_ESCAPE;
        case 0x24: return ENGINE_KEY_ENTER;
        case 0x31: return ENGINE_KEY_SPACE;

        default:   return ENGINE_KEY_UNKNOWN;
    }
}

// ============================================================
// Custom NSView (drawing + input)
// ============================================================
@interface GameView : NSView
@property (assign) Game *game; // non-owning
@end

@implementation GameView

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];

    // If you want buffer to match view size, resize here:
    ResizeBackbuffer((int)newSize.width, (int)newSize.height);

    if (self.game)
    {
        // If you want to allow dynamic resizing, you'd also need to resize/replace
        // the engine's display buffer. For now we keep engine resolution fixed.
        // So: we simply stretch blit in drawRect.
    }

    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    if (!gBackbuffer.memory) return;

    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    if (!ctx) return;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;

    CGDataProviderRef provider = CGDataProviderCreateWithData(
        NULL,
        gBackbuffer.memory,
        (size_t)gBackbuffer.pitch * (size_t)gBackbuffer.height,
        NULL
    );

    CGImageRef image = CGImageCreate(
        (size_t)gBackbuffer.width,
        (size_t)gBackbuffer.height,
        8,
        32,
        (size_t)gBackbuffer.pitch,
        colorSpace,
        bitmapInfo,
        provider,
        NULL,
        false,
        kCGRenderingIntentDefault
    );

    CGRect dest = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    CGContextDrawImage(ctx, dest, image);

    CGImageRelease(image);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);

    NSString *fpsString = [NSString stringWithFormat:@"FPS: %.1f", GlobalFPS];
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    [fpsString drawAtPoint:NSMakePoint(10, 10) withAttributes:attrs];
}

// ----- Input events -> engine input
- (void)keyDown:(NSEvent *)event
{
    if (!self.game) return;

    EngineKey k = MapKey(event.keyCode);
    if (k != ENGINE_KEY_UNKNOWN)
    {
        // pressed (one-frame) only when transitioning up->down
        if (!self.game->input.keys_down[k])
        {
            self.game->input.keys_pressed[k] = true;
        }
        self.game->input.keys_down[k] = true;
    }
}

- (void)keyUp:(NSEvent *)event
{
    if (!self.game) return;

    EngineKey k = MapKey(event.keyCode);
    if (k != ENGINE_KEY_UNKNOWN)
    {
        self.game->input.keys_down[k] = false;
    }
}

- (void)mouseDown:(NSEvent *)event
{
    if (!self.game) return;

    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    self.game->input.mouse.x = (int)p.x;
    self.game->input.mouse.y = (int)p.y;
    self.game->input.mouse.left = true;
}

- (void)mouseUp:(NSEvent *)event
{
    if (!self.game) return;

    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    self.game->input.mouse.x = (int)p.x;
    self.game->input.mouse.y = (int)p.y;
    self.game->input.mouse.left = false;
}

- (void)mouseMoved:(NSEvent *)event
{
    if (!self.game) return;

    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    self.game->input.mouse.x = (int)p.x;
    self.game->input.mouse.y = (int)p.y;
}

- (void)mouseDragged:(NSEvent *)event
{
    [self mouseMoved:event];
}

@end

// ============================================================
// App Delegate (window + tick loop)
// ============================================================
@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) GameView *view;

@property (assign) int display_width;
@property (assign) int display_height;
@property (assign) double targetSecondsPerFrame;

@property (assign) Game *game; // non-owning; lifetime owned by main (stack)
@end

@implementation AppDelegate
{
    double lastFrameTime;
    NSTimer *timer;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;

    NSRect frame = NSMakeRect(100, 100, self.display_width, self.display_height);

    self.window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskResizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];

    [self.window setTitle:@"GameFromScratch"];
    [self.window makeKeyAndOrderFront:nil];

    self.view = [[GameView alloc] initWithFrame:frame];
    self.view.game = self.game;

    [self.window setContentView:self.view];
    [self.window makeFirstResponder:self.view];

    // Allow mouse move events without clicking
    [self.window setAcceptsMouseMovedEvents:YES];

    // Minimal menu (enables Cmd-Q)
    NSMenu *menubar = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:appMenuItem];
    [NSApp setMainMenu:menubar];

    NSMenu *appMenu = [[NSMenu alloc] init];
    NSMenuItem *quitItem =
        [[NSMenuItem alloc] initWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"];
    [appMenu addItem:quitItem];
    [appMenuItem setSubmenu:appMenu];

    lastFrameTime = GetTimeSeconds();

    // Start the tick loop
    timer = [NSTimer scheduledTimerWithTimeInterval:self.targetSecondsPerFrame
                                             target:self
                                           selector:@selector(gameTick)
                                           userInfo:nil
                                            repeats:YES];
}

- (void)gameTick
{
    double now = GetTimeSeconds();
    double dt = now - lastFrameTime;
    lastFrameTime = now;

    if (dt > 0.0) GlobalFPS = 1.0 / dt;

    // Call engine update with dt (seconds)
    game_update(self.game, (float)dt);

    // Copy engine framebuffer -> platform backbuffer
    // Engine display is DISPLAY_WIDTH*DISPLAY_HEIGHT BGRA packed pixels
    size_t w = self.game->display_width;
    size_t h = self.game->display_height;

    // If backbuffer wasn't allocated yet or is wrong size, set it to engine size
    if (!gBackbuffer.memory || gBackbuffer.width != (int)w || gBackbuffer.height != (int)h)
    {
        ResizeBackbuffer((int)w, (int)h);
    }

    memcpy(gBackbuffer.memory, self.game->display, w * h * 4);

    [self.view setNeedsDisplay:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

@end

// ============================================================
// Entry point
// ============================================================
int main(int argc, const char *argv[])
{
    (void)argc; (void)argv;

    // Unbuffer stdout so printf shows immediately when launched from Terminal
    setvbuf(stdout, NULL, _IONBF, 0);

    Game game = game_init();

    @autoreleasepool
    {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        // Engine decides resolution for backbuffer (blitted into view)
        ResizeBackbuffer((int)game.display_width, (int)game.display_height);

        AppDelegate *delegate = [[AppDelegate alloc] init];
        delegate.game = &game;
        delegate.display_width  = (int)game.display_width;
        delegate.display_height = (int)game.display_height;
        delegate.targetSecondsPerFrame = 1.0 / (double)game.fps;

        [app setDelegate:delegate];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }

    return 0;
}