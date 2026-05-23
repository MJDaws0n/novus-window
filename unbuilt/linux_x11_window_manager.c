#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdbool.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

typedef struct _XDisplay Display;
typedef unsigned long XID;
typedef XID Window;
typedef XID Drawable;
typedef void *GC;
typedef unsigned long Atom;
typedef unsigned long KeySym;
typedef int Bool;

typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display *display;
    Window window;
    Window root;
    Window subwindow;
    unsigned long time;
    int x, y;
    int x_root, y_root;
    unsigned int state;
    unsigned int keycode;
    int same_screen;
} XKeyEvent;

typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display *display;
    Window window;
    int x, y;
    int width, height;
    int count;
} XExposeEvent;

typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display *display;
    Window event;
    Window window;
    int x, y;
    int width, height;
    int border_width;
    Window above;
    int override_redirect;
} XConfigureEvent;

typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display *display;
    Window window;
    Atom message_type;
    int format;
    union {
        char b[20];
        short s[10];
        long l[5];
    } data;
} XClientMessageEvent;

typedef union {
    int type;
    XKeyEvent xkey;
    XExposeEvent xexpose;
    XConfigureEvent xconfigure;
    XClientMessageEvent xclient;
    long pad[24];
} XEvent;

extern Display *XOpenDisplay(const char *);
extern int XDefaultScreen(Display *);
extern Window XRootWindow(Display *, int);
extern unsigned long XBlackPixel(Display *, int);
extern unsigned long XWhitePixel(Display *, int);
extern Window XCreateSimpleWindow(Display *, Window, int, int, unsigned int, unsigned int, unsigned int, unsigned long, unsigned long);
extern int XSelectInput(Display *, Window, long);
extern int XStoreName(Display *, Window, const char *);
extern int XMapWindow(Display *, Window);
extern int XUnmapWindow(Display *, Window);
extern GC XCreateGC(Display *, Drawable, unsigned long, void *);
extern int XSetForeground(Display *, GC, unsigned long);
extern int XFillRectangle(Display *, Drawable, GC, int, int, unsigned int, unsigned int);
extern int XFlush(Display *);
extern int XPending(Display *);
extern int XNextEvent(Display *, XEvent *);
extern int XDestroyWindow(Display *, Window);
extern int XCloseDisplay(Display *);
extern KeySym XLookupKeysym(XKeyEvent *, int);
extern Atom XInternAtom(Display *, const char *, Bool);
extern int XSetWMProtocols(Display *, Window, Atom *, int);
extern int XResizeWindow(Display *, Window, unsigned int, unsigned int);

#define KEY_PRESS 2
#define KEY_RELEASE 3
#define EXPOSE 12
#define CONFIGURE_NOTIFY 22
#define CLIENT_MESSAGE 33

#define KEY_PRESS_MASK (1L << 0)
#define KEY_RELEASE_MASK (1L << 1)
#define EXPOSURE_MASK (1L << 15)
#define STRUCTURE_NOTIFY_MASK (1L << 17)

#define XK_LEFT 0xff51UL
#define XK_UP 0xff52UL
#define XK_RIGHT 0xff53UL
#define XK_DOWN 0xff54UL
#define XK_SPACE 0x20UL
#define XK_A 0x61UL
#define XK_D 0x64UL
#define XK_S 0x73UL
#define XK_W 0x77UL
#define XK_ESCAPE 0xff1bUL

enum {
    INPUT_LEFT = 1,
    INPUT_RIGHT = 2,
    INPUT_JUMP = 4,
    INPUT_DOWN = 8,
    INPUT_QUIT = 16
};

struct rect_cmd {
    int x;
    int y;
    int w;
    int h;
    unsigned long color;
};

static Display *g_display = NULL;
static Window g_window = 0;
static GC g_gc = NULL;
static Atom g_wm_delete = 0;
static int g_width = 960;
static int g_height = 640;
static int g_input_mask = 0;
static unsigned long g_bg = 0x0012182aUL;
static struct rect_cmd g_rects[4096];
static int g_rect_count = 0;
static int g_running = 1;
static int g_client_fd = -1;
static char g_cmd_buf[8192];
static size_t g_cmd_len = 0;

static int send_line(const char *line) {
    if (g_client_fd < 0) {
        return -1;
    }
    size_t offset = 0;
    size_t total = strlen(line);
    while (offset < total) {
        ssize_t written = write(g_client_fd, line + offset, total - offset);
        if (written < 0) {
            if (errno == EINTR) {
                continue;
            }
            close(g_client_fd);
            g_client_fd = -1;
            return -1;
        }
        offset += (size_t)written;
    }
    return 0;
}

static unsigned long parse_color(const char *s) {
    long long v = strtoll(s, NULL, 10);
    uint32_t raw = (uint32_t)v;
    return (unsigned long)(raw & 0x00ffffffU);
}

static void render_frame(void) {
    XSetForeground(g_display, g_gc, g_bg);
    XFillRectangle(g_display, g_window, g_gc, 0, 0, (unsigned int)g_width, (unsigned int)g_height);
    for (int i = 0; i < g_rect_count; i++) {
        XSetForeground(g_display, g_gc, g_rects[i].color);
        XFillRectangle(g_display, g_window, g_gc, g_rects[i].x, g_rects[i].y, (unsigned int)g_rects[i].w, (unsigned int)g_rects[i].h);
    }
    XFlush(g_display);
}

static void set_key_mask(KeySym sym, int down) {
    int bit = 0;
    if (sym == XK_LEFT || sym == XK_A) bit = INPUT_LEFT;
    else if (sym == XK_RIGHT || sym == XK_D) bit = INPUT_RIGHT;
    else if (sym == XK_UP || sym == XK_W || sym == XK_SPACE) bit = INPUT_JUMP;
    else if (sym == XK_DOWN || sym == XK_S) bit = INPUT_DOWN;
    else if (sym == XK_ESCAPE) bit = INPUT_QUIT;
    if (!bit) return;
    if (down) g_input_mask |= bit;
    else g_input_mask &= ~bit;
}

static void pump_x11(void) {
    while (XPending(g_display) > 0) {
        XEvent ev;
        XNextEvent(g_display, &ev);
        if (ev.type == KEY_PRESS) {
            set_key_mask(XLookupKeysym(&ev.xkey, 0), 1);
        } else if (ev.type == KEY_RELEASE) {
            set_key_mask(XLookupKeysym(&ev.xkey, 0), 0);
        } else if (ev.type == EXPOSE) {
            render_frame();
        } else if (ev.type == CONFIGURE_NOTIFY) {
            if (ev.xconfigure.width > 0 && ev.xconfigure.height > 0) {
                g_width = ev.xconfigure.width;
                g_height = ev.xconfigure.height;
                render_frame();
            }
        } else if (ev.type == CLIENT_MESSAGE) {
            if ((Atom)ev.xclient.data.l[0] == g_wm_delete) {
                g_input_mask |= INPUT_QUIT;
            }
        }
    }
}

static void process_command(const char *line) {
    if (strncmp(line, "PING", 4) == 0) {
        send_line("PONG\n");
        return;
    }
    if (strncmp(line, "SHOW", 4) == 0) {
        XMapWindow(g_display, g_window);
        XFlush(g_display);
        send_line("OK\n");
        return;
    }
    if (strncmp(line, "HIDE", 4) == 0) {
        XUnmapWindow(g_display, g_window);
        XFlush(g_display);
        send_line("OK\n");
        return;
    }
    if (strncmp(line, "TITLE ", 6) == 0) {
        XStoreName(g_display, g_window, line + 6);
        XFlush(g_display);
        send_line("OK\n");
        return;
    }
    if (strncmp(line, "RESIZE ", 7) == 0) {
        int w = g_width;
        int h = g_height;
        if (sscanf(line + 7, "%dx%d", &w, &h) == 2 && w > 0 && h > 0) {
            g_width = w;
            g_height = h;
            XResizeWindow(g_display, g_window, (unsigned int)w, (unsigned int)h);
            XFlush(g_display);
        }
        send_line("OK\n");
        return;
    }
    if (strncmp(line, "CLEAR ", 6) == 0) {
        g_bg = parse_color(line + 6);
        g_rect_count = 0;
        send_line("OK\n");
        return;
    }
    if (strncmp(line, "RECT ", 5) == 0) {
        if (g_rect_count < (int)(sizeof(g_rects) / sizeof(g_rects[0]))) {
            int x = 0, y = 0, w = 0, h = 0;
            long long color = 0;
            if (sscanf(line + 5, "%d %d %d %d %lld", &x, &y, &w, &h, &color) == 5) {
                g_rects[g_rect_count].x = x;
                g_rects[g_rect_count].y = y;
                g_rects[g_rect_count].w = w;
                g_rects[g_rect_count].h = h;
                g_rects[g_rect_count].color = (unsigned long)(((uint32_t)color) & 0x00ffffffU);
                g_rect_count++;
            }
        }
        send_line("OK\n");
        return;
    }
    if (strncmp(line, "PRESENT", 7) == 0) {
        render_frame();
        send_line("OK\n");
        return;
    }
    if (strncmp(line, "INPUT", 5) == 0) {
        char out[64];
        snprintf(out, sizeof(out), "INPUT %d\n", g_input_mask);
        send_line(out);
        return;
    }
    if (strncmp(line, "SIZE", 4) == 0) {
        char out[64];
        snprintf(out, sizeof(out), "SIZE %dx%d\n", g_width, g_height);
        send_line(out);
        return;
    }
    if (strncmp(line, "QUIT", 4) == 0) {
        send_line("BYE\n");
        g_running = 0;
        return;
    }
    send_line("ERR\n");
}

static void process_client_bytes(const char *data, size_t len) {
    if (len == 0) {
        return;
    }

    if (g_cmd_len + len >= sizeof(g_cmd_buf)) {
        g_cmd_len = 0;
    }

    if (len >= sizeof(g_cmd_buf)) {
        data += len - (sizeof(g_cmd_buf) - 1);
        len = sizeof(g_cmd_buf) - 1;
    }

    memcpy(g_cmd_buf + g_cmd_len, data, len);
    g_cmd_len += len;
    g_cmd_buf[g_cmd_len] = '\0';

    size_t line_start = 0;
    for (size_t i = 0; i < g_cmd_len; i++) {
        if (g_cmd_buf[i] != '\n') {
            continue;
        }

        g_cmd_buf[i] = '\0';
        if (i > line_start && g_cmd_buf[i - 1] == '\r') {
            g_cmd_buf[i - 1] = '\0';
        }
        process_command(g_cmd_buf + line_start);
        line_start = i + 1;
    }

    if (line_start == 0) {
        return;
    }

    if (line_start < g_cmd_len) {
        memmove(g_cmd_buf, g_cmd_buf + line_start, g_cmd_len - line_start);
        g_cmd_len -= line_start;
    } else {
        g_cmd_len = 0;
    }
    g_cmd_buf[g_cmd_len] = '\0';
}

static int open_server(int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons((unsigned short)port);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -1;
    }
    if (listen(fd, 1) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

int main(int argc, char **argv) {
    const char *title = "Novus Window";
    const char *display_name = NULL;
    const char *xauthority = NULL;
    const char *home_dir = NULL;
    int port = 47832;

    signal(SIGPIPE, SIG_IGN);

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--port") == 0 && i + 1 < argc) {
            port = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--title") == 0 && i + 1 < argc) {
            title = argv[++i];
        } else if (strcmp(argv[i], "--display") == 0 && i + 1 < argc) {
            display_name = argv[++i];
        } else if (strcmp(argv[i], "--xauthority") == 0 && i + 1 < argc) {
            xauthority = argv[++i];
        } else if (strcmp(argv[i], "--home") == 0 && i + 1 < argc) {
            home_dir = argv[++i];
        } else if (strcmp(argv[i], "--width") == 0 && i + 1 < argc) {
            g_width = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--height") == 0 && i + 1 < argc) {
            g_height = atoi(argv[++i]);
        }
    }

    if (display_name && display_name[0] != '\0') {
        setenv("DISPLAY", display_name, 1);
    }
    if (xauthority && xauthority[0] != '\0') {
        setenv("XAUTHORITY", xauthority, 1);
    }
    if (home_dir && home_dir[0] != '\0') {
        setenv("HOME", home_dir, 1);
    }

    g_display = XOpenDisplay(NULL);
    if (!g_display) {
        fprintf(stderr, "window_manager_linux: failed to open X display\n");
        return 2;
    }

    int screen = XDefaultScreen(g_display);
    g_window = XCreateSimpleWindow(
        g_display,
        XRootWindow(g_display, screen),
        0, 0,
        (unsigned int)g_width,
        (unsigned int)g_height,
        1,
        XBlackPixel(g_display, screen),
        XWhitePixel(g_display, screen));
    XStoreName(g_display, g_window, title);
    XSelectInput(g_display, g_window, KEY_PRESS_MASK | KEY_RELEASE_MASK | EXPOSURE_MASK | STRUCTURE_NOTIFY_MASK);
    g_gc = XCreateGC(g_display, g_window, 0, NULL);
    g_wm_delete = XInternAtom(g_display, "WM_DELETE_WINDOW", 0);
    XSetWMProtocols(g_display, g_window, &g_wm_delete, 1);
    XMapWindow(g_display, g_window);
    XFlush(g_display);

    int server_fd = open_server(port);
    if (server_fd < 0) {
        fprintf(stderr, "window_manager_linux: failed to open server on %d\n", port);
        XDestroyWindow(g_display, g_window);
        XCloseDisplay(g_display);
        return 3;
    }

    while (g_running) {
        pump_x11();

        if (g_client_fd < 0) {
            fd_set accept_set;
            FD_ZERO(&accept_set);
            FD_SET(server_fd, &accept_set);
            struct timeval tv = {0, 50000};
            int rc = select(server_fd + 1, &accept_set, NULL, NULL, &tv);
            if (rc > 0 && FD_ISSET(server_fd, &accept_set)) {
                g_client_fd = accept(server_fd, NULL, NULL);
            }
            continue;
        }

        fd_set read_set;
        FD_ZERO(&read_set);
        FD_SET(g_client_fd, &read_set);
        struct timeval tv = {0, 16000};
        int rc = select(g_client_fd + 1, &read_set, NULL, NULL, &tv);
        if (rc < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (rc == 0) {
            continue;
        }
        if (FD_ISSET(g_client_fd, &read_set)) {
            char buf[4096];
            ssize_t n = read(g_client_fd, buf, sizeof(buf) - 1);
            if (n <= 0) {
                break;
            }
            process_client_bytes(buf, (size_t)n);
        }
    }

    if (g_client_fd >= 0) close(g_client_fd);
    close(server_fd);
    XDestroyWindow(g_display, g_window);
    XCloseDisplay(g_display);
    return 0;
}
