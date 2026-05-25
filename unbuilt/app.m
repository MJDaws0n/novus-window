// ---------------------------------------------------------------------------
// novus window_manager (macOS native, Cocoa-based)
//
// Out-of-process helper for the Novus `window` library. Speaks a line-based
// protocol over a UNIX domain socket. Draws into an offscreen 32-bit BGRA
// framebuffer using CoreGraphics and blits to an NSView via setNeedsDisplay.
//
// Protocol (one command per line, '\n' terminated):
//
//   OPEN <w> <h> <title>            -> OK\n
//   TITLE <text>                    -> OK\n
//   RESIZE <w> <h>                  -> OK\n
//   SHOW                            -> OK\n
//   HIDE                            -> OK\n
//   CLEAR <color>                   -> (no ack)   begins a new frame
//   RECT <x> <y> <w> <h> <color>    -> (no ack)
//   PRESENT                         -> OK <mask>\n  swap + return input mask
//   INPUT                           -> OK <mask>\n
//   SIZE                            -> SIZE <w> <h>\n
//   PING                            -> PONG\n
//   QUIT                            -> BYE\n
//
// Colors are 32-bit ARGB integers in decimal or hex (0xAARRGGBB).
// Input mask bits: LEFT=1, RIGHT=2, JUMP=4, DOWN=8, QUIT=16.
//
// Build (Apple Silicon / Intel):
//   clang -O2 -fobjc-arc -framework Cocoa \
//     lib/window/unbuilt/app.m -o lib/window/window_manager
// ---------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#define DEFAULT_SOCKET_PATH "/tmp/novus_wm.sock"
#define DEFAULT_WIDTH       960
#define DEFAULT_HEIGHT      640
#define READ_BUF            65536

// Input bitmask values (must match the Novus-side constants).
enum {
    INPUT_LEFT  = 1,
    INPUT_RIGHT = 2,
    INPUT_JUMP  = 4,
    INPUT_DOWN  = 8,
    INPUT_QUIT  = 16,
};

// ---------------------------------------------------------------------------
// Globals (single-window app)
// ---------------------------------------------------------------------------
static NSWindow         *g_window      = nil;
static NSView           *g_view        = nil;
static CGContextRef      g_back        = NULL;   // offscreen bitmap context
static uint8_t          *g_back_pixels = NULL;
static int               g_width       = DEFAULT_WIDTH;
static int               g_height      = DEFAULT_HEIGHT;
static pthread_mutex_t   g_fb_lock     = PTHREAD_MUTEX_INITIALIZER;
static volatile uint32_t g_input_mask  = 0;
static volatile bool     g_should_quit = false;
static int               g_client_fd   = -1;
static int               g_listen_fd   = -1;
static char              g_sock_path[256] = DEFAULT_SOCKET_PATH;

// ---------------------------------------------------------------------------
// Custom view: blits the offscreen framebuffer
// ---------------------------------------------------------------------------
@interface NovusView : NSView
@end

@implementation NovusView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)preservesContentDuringLiveResize { return NO; }

- (void)drawRect:(NSRect)dirty {
    [[NSColor blackColor] setFill];
    NSRectFill(dirty);

    int fb_width = 0;
    int fb_height = 0;
    pthread_mutex_lock(&g_fb_lock);
    if (g_back == NULL) {
        pthread_mutex_unlock(&g_fb_lock);
        return;
    }
    fb_width = g_width;
    fb_height = g_height;
    CGImageRef img = CGBitmapContextCreateImage(g_back);
    pthread_mutex_unlock(&g_fb_lock);

    if (img == NULL) { return; }

    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGRect r = CGRectMake(0, 0, fb_width, fb_height);
    CGContextSaveGState(ctx);
    // Our framebuffer is top-left origin; flip Y for the view.
    CGContextTranslateCTM(ctx, 0, self.bounds.size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    CGContextDrawImage(ctx, r, img);
    CGContextRestoreGState(ctx);

    CGImageRelease(img);
}
@end

// ---------------------------------------------------------------------------
// App delegate
// ---------------------------------------------------------------------------
@interface NovusAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@end

@implementation NovusAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
}
- (void)windowWillClose:(NSNotification *)note {
    (void)note;
    g_input_mask |= INPUT_QUIT;
}
- (void)windowDidResize:(NSNotification *)note {
    (void)note;
    [g_view setNeedsDisplay:YES];
}
@end

// ---------------------------------------------------------------------------
// Framebuffer management
// ---------------------------------------------------------------------------
static void fb_destroy_locked(void) {
    if (g_back) {
        CGContextRelease(g_back);
        g_back = NULL;
    }
    if (g_back_pixels) {
        free(g_back_pixels);
        g_back_pixels = NULL;
    }
}

static void fb_create_locked(int w, int h) {
    fb_destroy_locked();
    size_t bytes = (size_t)w * (size_t)h * 4;
    g_back_pixels = (uint8_t *)calloc(1, bytes);
    if (!g_back_pixels) { return; }

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    g_back = CGBitmapContextCreate(g_back_pixels, w, h, 8, (size_t)w * 4, cs,
                                   kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(cs);
}

static void fb_fill_rect(int x, int y, int w, int h, uint32_t color) {
    if (g_back_pixels == NULL) { return; }
    int x0 = x < 0 ? 0 : x;
    int y0 = y < 0 ? 0 : y;
    int x1 = x + w; if (x1 > g_width)  x1 = g_width;
    int y1 = y + h; if (y1 > g_height) y1 = g_height;
    if (x0 >= x1 || y0 >= y1) { return; }

    // Strip alpha → solid color; framebuffer ignores alpha but we write
    // it anyway as 0xFF for consistency.
    uint32_t bgra = 0xFF000000u | (color & 0x00FFFFFFu);

    for (int yy = y0; yy < y1; ++yy) {
        uint32_t *row = (uint32_t *)(g_back_pixels + ((size_t)yy * (size_t)g_width + (size_t)x0) * 4);
        for (int xx = x0; xx < x1; ++xx) { row[xx - x0] = bgra; }
    }
}

static void fb_clear(uint32_t color) {
    fb_fill_rect(0, 0, g_width, g_height, color);
}

// ---------------------------------------------------------------------------
// Main-thread helpers
// ---------------------------------------------------------------------------
static void on_main(void (^block)(void)) {
    if ([NSThread isMainThread]) { block(); return; }
    dispatch_sync(dispatch_get_main_queue(), block);
}

static void window_create(int w, int h, NSString *title) {
    g_width  = w;
    g_height = h;

    pthread_mutex_lock(&g_fb_lock);
    fb_create_locked(w, h);
    pthread_mutex_unlock(&g_fb_lock);

    NSRect frame = NSMakeRect(100, 100, w, h);
    NSUInteger style = NSWindowStyleMaskTitled
                     | NSWindowStyleMaskClosable
                     | NSWindowStyleMaskMiniaturizable
                     | NSWindowStyleMaskResizable;
    g_window = [[NSWindow alloc] initWithContentRect:frame
                                           styleMask:style
                                             backing:NSBackingStoreBuffered
                                               defer:NO];
    [g_window setTitle:(title ?: @"Novus")];
    g_view = [[NovusView alloc] initWithFrame:NSMakeRect(0, 0, w, h)];
    [g_window setContentView:g_view];
    [g_window setReleasedWhenClosed:NO];
    NovusAppDelegate *del = (NovusAppDelegate *)[NSApp delegate];
    [g_window setDelegate:del];

    // Key event monitor — updates the input bitmask.
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskKeyUp)
                                          handler:^NSEvent *(NSEvent *e) {
        bool down = (e.type == NSEventTypeKeyDown);
        unsigned short code = e.keyCode;
        uint32_t bit = 0;
        // macOS virtual keycodes.
        // Arrows: Left=123 Right=124 Down=125 Up=126. Space=49. WASD: A=0 D=2 S=1 W=13. Esc=53.
        if (code == 123 || code == 0)  { bit = INPUT_LEFT;  }
        if (code == 124 || code == 2)  { bit = INPUT_RIGHT; }
        if (code == 126 || code == 13 || code == 49) { bit = INPUT_JUMP; }
        if (code == 125 || code == 1)  { bit = INPUT_DOWN;  }
        if (code == 53)                { if (down) { g_input_mask |= INPUT_QUIT; } return nil; }
        if (bit != 0) {
            if (down) { g_input_mask |=  bit; }
            else      { g_input_mask &= ~bit; }
        }
        return nil;  // swallow so they don't beep
    }];
}

static void window_show(void) {
    [g_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

static void window_hide(void) { [g_window orderOut:nil]; }

static void window_resize(int w, int h) {
    g_width = w;
    g_height = h;
    pthread_mutex_lock(&g_fb_lock);
    fb_create_locked(w, h);
    pthread_mutex_unlock(&g_fb_lock);
    NSRect cf = [g_window contentRectForFrameRect:[g_window frame]];
    cf.size.width = w;
    cf.size.height = h;
    NSRect ff = [g_window frameRectForContentRect:cf];
    [g_window setFrame:ff display:YES animate:NO];
    [g_view setFrame:NSMakeRect(0, 0, w, h)];
}

static void window_present(void) { [g_view setNeedsDisplay:YES]; }

static void window_title(NSString *t) { [g_window setTitle:t]; }

static void window_size(int *w, int *h) {
    if (g_window == nil) {
        *w = g_width;
        *h = g_height;
        return;
    }

    NSRect bounds = [[g_window contentView] bounds];
    *w = (int)(bounds.size.width + 0.5);
    *h = (int)(bounds.size.height + 0.5);
}

// ---------------------------------------------------------------------------
// Line parsing
// ---------------------------------------------------------------------------
static int read_line(int fd, char *buf, int cap) {
    int n = 0;
    while (n < cap - 1) {
        char c;
        ssize_t r = read(fd, &c, 1);
        if (r == 0) { return -1; }
        if (r < 0)  { if (errno == EINTR) continue; return -1; }
        if (c == '\n') { break; }
        buf[n++] = c;
    }
    buf[n] = 0;
    return n;
}

static int write_all(int fd, const char *s, size_t n) {
    size_t off = 0;
    while (off < n) {
        ssize_t w = write(fd, s + off, n - off);
        if (w < 0) { if (errno == EINTR) continue; return -1; }
        off += (size_t)w;
    }
    return 0;
}

static int reply(int fd, const char *s) { return write_all(fd, s, strlen(s)); }

// Parse N ints separated by spaces. Returns count parsed.
static int parse_ints(const char *s, int64_t *out, int max) {
    int n = 0;
    while (*s && n < max) {
        while (*s == ' ') ++s;
        if (!*s) break;
        char *end = NULL;
        int base = 10;
        if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) { base = 16; }
        long long v = strtoll(s, &end, base);
        if (end == s) break;
        out[n++] = (int64_t)v;
        s = end;
    }
    return n;
}

// ---------------------------------------------------------------------------
// Command dispatch
// ---------------------------------------------------------------------------
static void handle_command(int fd, char *line) {
    char cmd[32];
    int i = 0;
    while (line[i] && line[i] != ' ' && i < (int)sizeof(cmd) - 1) {
        cmd[i] = line[i]; ++i;
    }
    cmd[i] = 0;
    const char *rest = line[i] ? line + i + 1 : line + i;

    if (strcmp(cmd, "RECT") == 0) {
        int64_t a[5] = {0};
        if (parse_ints(rest, a, 5) == 5) {
            fb_fill_rect((int)a[0], (int)a[1], (int)a[2], (int)a[3], (uint32_t)a[4]);
        }
        // no ack — fire-and-forget for throughput
        return;
    }
    if (strcmp(cmd, "CLEAR") == 0) {
        int64_t a[1] = {0};
        if (parse_ints(rest, a, 1) == 1) { fb_clear((uint32_t)a[0]); }
        return;
    }
    if (strcmp(cmd, "PRESENT") == 0) {
        on_main(^{ window_present(); });
        char buf[32];
        int n = snprintf(buf, sizeof(buf), "OK %u\n", (unsigned)g_input_mask);
        write_all(fd, buf, (size_t)n);
        return;
    }
    if (strcmp(cmd, "INPUT") == 0) {
        char buf[32];
        int n = snprintf(buf, sizeof(buf), "OK %u\n", (unsigned)g_input_mask);
        write_all(fd, buf, (size_t)n);
        return;
    }
    if (strcmp(cmd, "OPEN") == 0) {
        int64_t a[2] = {DEFAULT_WIDTH, DEFAULT_HEIGHT};
        int np = parse_ints(rest, a, 2);
        const char *title = rest;
        for (int k = 0; k < np; ++k) {
            while (*title == ' ') ++title;
            while (*title && *title != ' ') ++title;
        }
        while (*title == ' ') ++title;
        NSString *t = [NSString stringWithUTF8String:(*title ? title : "Novus")];
        int aw = (int)a[0], ah = (int)a[1];
        on_main(^{ window_create(aw, ah, t); });
        reply(fd, "OK\n");
        return;
    }
    if (strcmp(cmd, "TITLE") == 0) {
        NSString *t = [NSString stringWithUTF8String:rest];
        on_main(^{ window_title(t); });
        reply(fd, "OK\n");
        return;
    }
    if (strcmp(cmd, "RESIZE") == 0) {
        int64_t a[2] = {0,0};
        if (parse_ints(rest, a, 2) == 2) {
            int rw = (int)a[0], rh = (int)a[1];
            on_main(^{ window_resize(rw, rh); });
        }
        reply(fd, "OK\n");
        return;
    }
    if (strcmp(cmd, "SHOW") == 0)  { on_main(^{ window_show(); }); reply(fd, "OK\n"); return; }
    if (strcmp(cmd, "HIDE") == 0)  { on_main(^{ window_hide(); }); reply(fd, "OK\n"); return; }
    if (strcmp(cmd, "PING") == 0)  { reply(fd, "PONG\n"); return; }
    if (strcmp(cmd, "SIZE") == 0) {
        __block int sw = g_width;
        __block int sh = g_height;
        on_main(^{ window_size(&sw, &sh); });
        char buf[64];
        int n = snprintf(buf, sizeof(buf), "SIZE %d %d\n", sw, sh);
        write_all(fd, buf, (size_t)n);
        return;
    }
    if (strcmp(cmd, "QUIT") == 0) {
        reply(fd, "BYE\n");
        g_should_quit = true;
        // Wake the main run loop so it can notice and exit.
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSApp stop:nil];
            NSEvent *e = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                            location:NSZeroPoint
                                       modifierFlags:0
                                           timestamp:0
                                        windowNumber:0
                                             context:nil
                                             subtype:0
                                               data1:0
                                               data2:0];
            [NSApp postEvent:e atStart:YES];
        });
        return;
    }
    // Unknown
    reply(fd, "ERR unknown_command\n");
}

// ---------------------------------------------------------------------------
// Socket server (background thread)
// ---------------------------------------------------------------------------
static void *server_thread(void *arg) {
    (void)arg;
    char buf[READ_BUF];
    while (!g_should_quit) {
        int cfd = accept(g_listen_fd, NULL, NULL);
        if (cfd < 0) {
            if (errno == EINTR) continue;
            break;
        }
        g_client_fd = cfd;
        while (!g_should_quit) {
            int n = read_line(cfd, buf, sizeof(buf));
            if (n < 0) break;
            handle_command(cfd, buf);
        }
        close(cfd);
        g_client_fd = -1;
    }
    return NULL;
}

static int socket_listen(const char *path) {
    unlink(path);
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) { close(fd); return -1; }
    if (listen(fd, 4) < 0) { close(fd); return -1; }
    return fd;
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
static void usage(const char *p) {
    fprintf(stderr, "usage: %s [--socket PATH] [--title TITLE] [--auto-show]\n", p);
}

int main(int argc, char **argv) {
    const char *title = "Novus";
    bool auto_show = false;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--socket") == 0 && i + 1 < argc) {
            strncpy(g_sock_path, argv[++i], sizeof(g_sock_path) - 1);
        } else if (strcmp(argv[i], "--title") == 0 && i + 1 < argc) {
            title = argv[++i];
        } else if (strcmp(argv[i], "--auto-show") == 0) {
            auto_show = true;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]); return 0;
        }
    }

    signal(SIGPIPE, SIG_IGN);

    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        NovusAppDelegate *del = [[NovusAppDelegate alloc] init];
        [NSApp setDelegate:del];

        // Pre-create a window so the client sees something even before OPEN.
        NSString *t = [NSString stringWithUTF8String:title];
        window_create(DEFAULT_WIDTH, DEFAULT_HEIGHT, t);
        if (auto_show) { window_show(); }

        g_listen_fd = socket_listen(g_sock_path);
        if (g_listen_fd < 0) {
            fprintf(stderr, "failed to bind socket %s: %s\n", g_sock_path, strerror(errno));
            return 1;
        }

        pthread_t tid;
        pthread_create(&tid, NULL, server_thread, NULL);
        pthread_detach(tid);

        [NSApp run];

        if (g_listen_fd >= 0) close(g_listen_fd);
        unlink(g_sock_path);
    }
    return 0;
}
