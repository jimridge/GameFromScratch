#import <Cocoa/Cocoa.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

// ============================================================
// Global platform state
// ============================================================

static bool GlobalRunning = true;
// static Backbuffer GlobalBackbuffer = {0};


// ============================================================
// Custom NSView for drawing + input
// ============================================================

@interface GameView : NSView
@end

@implementation GameView

- (BOOL)acceptsFirstResponder {
    return YES;
}

// NOTE Key and Mouse events

// NOTE Example for handling specific keypresses
// TODO Expand on this
// - (void)keyDown:(NSEvent *)event {
//     unsigned short key = event.keyCode;

//     switch (key) {
//         case 0x00: /* A */ break;
//         case 0x01: /* S */ break;
//         case 0x02: /* D */ break;
//         case 0x0D: /* W */ break;
//         case 0x35: /* ESC */ break;
//     }

//     engine_input.keys[key] = true;
// }

- (void)keyDown:(NSEvent *)event
{
    NSLog(@"Key down: %@", event.charactersIgnoringModifiers);
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    NSLog(@"Mouse down at %.1f, %.1f", p.x, p.y);
}

- (void)keyUp:(NSEvent *)event {
    NSLog(@"Key up: %@", event.charactersIgnoringModifiers);
}
@end



// ============================================================
// App delegate (window + menu + quit handling)
// ============================================================
@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) GameView *view;
@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // NOTE Window
    // TODO Break this out into GLOBAL functions or similar
    NSRect frame = NSMakeRect(100, 100, 960, 540);
    self.window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskResizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];

    [self.window setTitle:@"GameFromScratch"];
    [self.window makeKeyAndOrderFront:nil];

    // View
    self.view = [[GameView alloc] initWithFrame:frame];
    [self.window setContentView:self.view];
    [self.window makeFirstResponder:self.view];

    // ResizeBackbuffer(800, 600);

    // NOTE Add the menu item to quit the game (Cmd-Q)
    NSMenu *menubar = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:appMenuItem];
    [NSApp setMainMenu:menubar];

    NSMenu *appMenu = [[NSMenu alloc] init];
    NSString *quitTitle =
        [@"Quit " stringByAppendingString:[[NSProcessInfo processInfo] processName]];
    NSMenuItem *quitItem =
        [[NSMenuItem alloc] initWithTitle:quitTitle
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"];
    [appMenu addItem:quitItem];
    [appMenuItem setSubmenu:appMenu];

    // NOTE Timer for game loop
    // [NSTimer scheduledTimerWithTimeInterval:(1.0 / 60.0)
    //                                  target:self
    //                                selector:@selector(gameLoop)
    //                                userInfo:nil
    //                                 repeats:YES];
}

- (void)gameLoop
{
    if (!GlobalRunning)
    {
        [NSApp terminate:nil];
    }

    [self.view setNeedsDisplay:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

@end

// ============================================================
// Entry point (like WinMain)
// ============================================================

int main(int argc, const char *argv[])
{
    // NOTE Required to suppres clang compiler errors
    (void)argc;
    (void)argv;

    @autoreleasepool
    {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
