#!/usr/bin/env bash
# Build the macOS native window-manager helper.
#
# The helper is a tiny Cocoa app that owns the NSWindow + framebuffer and
# speaks a line-based protocol over a UNIX domain socket. The Novus side
# of the library (`platforms/darwin/*.nov`) spawns and talks to this binary.
#
# Nothing here is platform-specific to a Mac model — it builds a universal
# (arm64 + x86_64) Mach-O so a single binary works on both Apple Silicon and
# Intel Macs.
#
# Usage:
#   ./unbuilt/build.sh                  # universal binary -> ./window_manager
#   ./unbuilt/build.sh arm64            # arm64-only
#   ./unbuilt/build.sh x86_64           # x86_64-only
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH_FLAGS="-arch arm64 -arch x86_64"
case "${1:-}" in
    arm64)  ARCH_FLAGS="-arch arm64"  ;;
    x86_64|amd64) ARCH_FLAGS="-arch x86_64" ;;
    "") ;;
    *) echo "unknown arch: $1" >&2; exit 1 ;;
esac

clang -O2 -Wall -Wextra -fobjc-arc $ARCH_FLAGS \
    -framework Cocoa \
    unbuilt/app.m \
    -o window_manager

echo "built window_manager:"
file window_manager
