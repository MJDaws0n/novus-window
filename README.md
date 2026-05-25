# novus-window

Cross-platform windowing and basic graphics.

A library for the [Novus](https://github.com/MJDaws0n/Novus) language, installable
via [Nox](https://github.com/MJDaws0n/Nox).

## Install

```sh
nox pull window
```

## Documentation

See [`docs.md`](docs.md) for the full API reference.

## Import

```novus
import lib/window window;
```

## Platform support

| Platform        | Backend                                | Status                  |
|-----------------|----------------------------------------|-------------------------|
| Linux x86_64    | In-process X11 wire protocol (pure Novus, syscalls) | Tested                  |
| Linux arm64     | In-process X11 wire protocol           | Compiles; not hardware-tested |
| macOS arm64     | Out-of-process Cocoa helper (`window_manager`) | Tested                  |
| macOS x86_64    | Same helper (universal binary)         | Compiles; not hardware-tested |
| Windows amd64   | Stub                                   | Not yet implemented     |
| Windows x86     | Stub                                   | Not yet implemented     |

### macOS helper

The macOS backend ships a tiny native helper binary (`window_manager`) that
owns the `NSWindow` + framebuffer and speaks a line-based protocol over a
UNIX domain socket. Build it with:

```sh
cd lib/window && ./unbuilt/build.sh
```

This produces a universal (arm64 + x86_64) Mach-O at `lib/window/window_manager`.

The reason the macOS backend is out-of-process (unlike Linux's in-process
X11) is that macOS does not expose a public protocol for its window server —
all native windows must go through `AppKit`/`CoreGraphics`, which is linked
into the helper. The Novus side of the library is still pure Novus
(syscalls only).
