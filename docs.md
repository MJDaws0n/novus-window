# window

Cross-platform windowing and basic graphics.

This document is auto-generated from the function signatures in this repository. 
It lists every public function the library exposes.

## Install

```sh
nox pull window
```

## Import

```novus
import lib/window window;
```

## Functions

### `display_socket_path`

```novus
fn display_socket_path(display: str) -> str;
```
_Defined in: `linux_amd64.nov`_

### `init_x11`

```novus
fn init_x11(title: str) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `keycode_bit`

```novus
fn keycode_bit(code: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `make_sockaddr_un`

```novus
fn make_sockaddr_un(path: str) -> str;
```
_Defined in: `linux_amd64.nov`_

### `make_zero_buf`

```novus
fn make_zero_buf(size: i32) -> str;
```
_Defined in: `linux_amd64.nov`_

### `next_resource_id`

```novus
fn next_resource_id() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `pad4`

```novus
fn pad4(n: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `parse_display_num`

```novus
fn parse_display_num(display: str) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `poll_x`

```novus
fn poll_x(timeout_ms: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `process_x_message`

```novus
fn process_x_message(pkt: str) -> void;
```
_Defined in: `linux_amd64.nov`_

### `read_exact`

```novus
fn read_exact(fd: i32, count: i32) -> str;
```
_Defined in: `linux_amd64.nov`_

### `read_u16_be`

```novus
fn read_u16_be(buf: str, off: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `read_u16_le`

```novus
fn read_u16_le(buf: str, off: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `read_u32_le`

```novus
fn read_u32_le(buf: str, off: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `read_xauthority_cookie`

```novus
fn read_xauthority_cookie(path: str, display_num: i32) -> str;
```
_Defined in: `linux_amd64.nov`_

### `render_background`

```novus
fn render_background() -> void;
```
_Defined in: `linux_amd64.nov`_

### `sock_connect`

```novus
fn sock_connect(fd: i32, addr_ptr: u64, addr_len: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `sock_socket`

```novus
fn sock_socket(domain: i32, kind: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `sys_close`

```novus
fn sys_close(fd: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `sys_read`

```novus
fn sys_read(fd: i32, addr: u64, count: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `sys_write`

```novus
fn sys_write(fd: i32, addr: u64, count: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `syscall_result_i32`

```novus
fn syscall_result_i32() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `syscall_result_i64`

```novus
fn syscall_result_i64() -> i64;
```
_Defined in: `linux_amd64.nov`_

### `to_u8`

```novus
fn to_u8(v: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_clear`

```novus
fn wm_clear(fd: i32, color: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_close`

```novus
fn wm_close(fd: i32) -> void;
```
_Defined in: `darwin_arm64.nov`_

### `wm_connect`

```novus
fn wm_connect(sock_path: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_escape_arg`

```novus
fn wm_escape_arg(arg: str) -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_escape_js`

```novus
fn wm_escape_js(s: str) -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_exe_default`

```novus
fn wm_exe_default() -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_hide`

```novus
fn wm_hide(fd: i32) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_input`

```novus
fn wm_input(fd: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_input_down`

```novus
fn wm_input_down() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_input_jump`

```novus
fn wm_input_jump() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_input_left`

```novus
fn wm_input_left() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_input_quit`

```novus
fn wm_input_quit() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_input_right`

```novus
fn wm_input_right() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_jseval`

```novus
fn wm_jseval(fd: i32, code: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_navigate`

```novus
fn wm_navigate(fd: i32, url: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_open`

```novus
fn wm_open(title: str, exe_path: str, sock_path: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_open_default`

```novus
fn wm_open_default(title: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_open_serve`

```novus
fn wm_open_serve(title: str, root_dir: str, index_path: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_parse_port`

```novus
fn wm_parse_port(resp: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_ping`

```novus
fn wm_ping(fd: i32) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_present`

```novus
fn wm_present(fd: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_quit`

```novus
fn wm_quit(fd: i32) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_rect`

```novus
fn wm_rect(fd: i32, x: i32, y: i32, width: i32, height: i32, color: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `wm_recv_js_msg`

```novus
fn wm_recv_js_msg(fd: i32) -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_recv_line`

```novus
fn wm_recv_line(fd: i32, buf_len: i32) -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_recv_ok`

```novus
fn wm_recv_ok(fd: i32) -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_resize`

```novus
fn wm_resize(fd: i32, width: i32, height: i32) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_send_cmd`

```novus
fn wm_send_cmd(fd: i32, cmd: str, arg: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_send_line`

```novus
fn wm_send_line(fd: i32, line: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_send_to_js`

```novus
fn wm_send_to_js(fd: i32, msg: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_serve`

```novus
fn wm_serve(fd: i32, root_dir: str) -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_show`

```novus
fn wm_show(fd: i32) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_size`

```novus
fn wm_size(fd: i32) -> str;
```
_Defined in: `linux_amd64.nov`_

### `wm_sleep_ms`

```novus
fn wm_sleep_ms(ms: i32) -> void;
```
_Defined in: `darwin_arm64.nov`_

### `wm_sock_path_default`

```novus
fn wm_sock_path_default() -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_sockaddr_un_make`

```novus
fn wm_sockaddr_un_make(path: str) -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_socket`

```novus
fn wm_socket() -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_spawn`

```novus
fn wm_spawn(exe_path: str, sock_path: str, title: str, auto_show: bool) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_start`

```novus
fn wm_start(sock_path: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_start_auto`

```novus
fn wm_start_auto(exe_path: str, sock_path: str, title: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_syscall0`

```novus
fn wm_syscall0(nr: i64) -> u64;
```
_Defined in: `darwin_arm64.nov`_

### `wm_syscall1_i32`

```novus
fn wm_syscall1_i32(nr: i64, a0: i32) -> u64;
```
_Defined in: `darwin_arm64.nov`_

### `wm_syscall3`

```novus
fn wm_syscall3(nr: i64, a0: i32, a1: u64, a2: i32) -> u64;
```
_Defined in: `darwin_arm64.nov`_

### `wm_syscall3_i32`

```novus
fn wm_syscall3_i32(nr: i64, a0: i32, a1: i32, a2: i32) -> u64;
```
_Defined in: `darwin_arm64.nov`_

### `wm_title`

```novus
fn wm_title(fd: i32, title: str) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_to_u8`

```novus
fn wm_to_u8(v: i32) -> i32;
```
_Defined in: `darwin_arm64.nov`_

### `wm_unescape_arg`

```novus
fn wm_unescape_arg(arg: str) -> str;
```
_Defined in: `darwin_arm64.nov`_

### `wm_unlink`

```novus
fn wm_unlink(path: str) -> void;
```
_Defined in: `darwin_arm64.nov`_

### `wm_write_i32_le`

```novus
fn wm_write_i32_le(buf: str, offset: i32, val: i32) -> void;
```
_Defined in: `darwin_arm64.nov`_

### `write_all`

```novus
fn write_all(fd: i32, data: str, count: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `write_u16_be`

```novus
fn write_u16_be(buf: str, off: i32, val: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `write_u16_le`

```novus
fn write_u16_le(buf: str, off: i32, val: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `write_u32_le`

```novus
fn write_u32_le(buf: str, off: i32, val: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_change_gc_color`

```novus
fn x_change_gc_color(color: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_change_property`

```novus
fn x_change_property(window_id: i32, property_atom: i32, type_atom: i32, format_bits: i32, data: str, item_count: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_connect`

```novus
fn x_connect() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_copy_backbuffer_to_window`

```novus
fn x_copy_backbuffer_to_window() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_create_gc`

```novus
fn x_create_gc() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_create_pixmap`

```novus
fn x_create_pixmap(width: i32, height: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_create_window`

```novus
fn x_create_window() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_drawable`

```novus
fn x_drawable() -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_ensure_backbuffer`

```novus
fn x_ensure_backbuffer() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_file_open_read`

```novus
fn x_file_open_read(path: str) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_file_seek`

```novus
fn x_file_seek(fd: i32, offset: u64, whence: i32) -> i64;
```
_Defined in: `linux_amd64.nov`_

### `x_file_size`

```novus
fn x_file_size(fd: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_fill_rect`

```novus
fn x_fill_rect(x: i32, y: i32, w: i32, h: i32, color: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_free_pixmap`

```novus
fn x_free_pixmap(pixmap_id: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_init_request_buffers`

```novus
fn x_init_request_buffers() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_intern_atom`

```novus
fn x_intern_atom(name: str) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_map_window`

```novus
fn x_map_window() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_pump_events`

```novus
fn x_pump_events() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_read_file`

```novus
fn x_read_file(path: str) -> str;
```
_Defined in: `linux_amd64.nov`_

### `x_read_message`

```novus
fn x_read_message() -> str;
```
_Defined in: `linux_amd64.nov`_

### `x_read_setup`

```novus
fn x_read_setup(fd: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_resize_window`

```novus
fn x_resize_window(width: i32, height: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_send_setup`

```novus
fn x_send_setup(fd: i32, cookie: str) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_set8`

```novus
fn x_set8(buf: str, off: i32, val: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_set_title`

```novus
fn x_set_title(title: str) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_set_wm_protocols`

```novus
fn x_set_wm_protocols() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_setup`

```novus
fn x_setup(fd: i32) -> i32;
```
_Defined in: `linux_amd64.nov`_

### `x_sync`

```novus
fn x_sync() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_unmap_window`

```novus
fn x_unmap_window() -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_write_u16_le`

```novus
fn x_write_u16_le(buf: str, off: i32, val: i32) -> void;
```
_Defined in: `linux_amd64.nov`_

### `x_write_u32_le`

```novus
fn x_write_u32_le(buf: str, off: i32, val: i32) -> void;
```
_Defined in: `linux_amd64.nov`_
