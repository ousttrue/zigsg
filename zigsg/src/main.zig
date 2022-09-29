const std = @import("std");
const builtin = @import("builtin");
const zigmui = @import("zigmui");
const gl = @import("./gl.zig");

// init OpenGL by glad
const GLADloadproc = fn ([*c]const u8) callconv(.C) ?*anyopaque;
pub extern fn gladLoadGL(*const GLADloadproc) c_int;
pub fn loadproc(ptr: *const anyopaque) void {
    if (builtin.target.cpu.arch != .wasm32) {
        _ = gladLoadGL(@ptrCast(*const GLADloadproc, ptr));
    }
}

export fn ENGINE_init(p: *const anyopaque) callconv(.C) void {
    if (builtin.target.cpu.arch != .wasm32) {
        _ = gladLoadGL(@ptrCast(*const GLADloadproc, @alignCast(@alignOf(GLADloadproc), p)));
    }
}

export fn ENGINE_deinit() callconv(.C) void {}

export fn ENGINE_mousemove(x: c_int, y: c_int) callconv(.C) void {
    _ = x;
    _ = y;
}

export fn ENGINE_mousebutton_press(button: c_int) callconv(.C) void {
    _ = button;
}

export fn ENGINE_mousebutton_release(button: c_int) callconv(.C) void {
    _ = button;
}

export fn ENGINE_mousewheel(x: c_int, y: c_int) callconv(.C) void {
    _ = x;
    _ = y;
}

export fn ENGINE_key_press(ch: c_int) callconv(.C) void {
    _ = ch;
}

export fn ENGINE_key_release(ch: c_int) callconv(.C) void {
    _ = ch;
}

export fn ENGINE_unicode(cp: c_uint) callconv(.C) void {
    _ = cp;
}

export fn ENGINE_render(width: c_int, height: c_int) callconv(.C) zigmui.CURSOR_SHAPE {
    gl.viewport(0, 0, width, height);
    gl.clearColor(0.2, 0.3, 0.4, 1.0);
    gl.clear(gl.GL_COLOR_BUFFER_BIT);
    return .ARROW;
}
