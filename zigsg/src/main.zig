const std = @import("std");
const builtin = @import("builtin");
const zigmui = @import("zigmui");
const atlas = @import("atlas");
const gl = @import("gl");

// init OpenGL by glad
const GLADloadproc = fn ([*c]const u8) callconv(.C) ?*anyopaque;
pub extern fn gladLoadGL(*const GLADloadproc) c_int;
pub fn loadproc(ptr: *const anyopaque) void {
    if (builtin.target.cpu.arch != .wasm32) {
        _ = gladLoadGL(@ptrCast(*const GLADloadproc, ptr));
    }
}

var g_ctx: ?*zigmui.Context = null;
var g_gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var g_allocator: std.mem.Allocator = undefined;

export fn ENGINE_init(p: *const anyopaque) callconv(.C) void {
    if (builtin.target.cpu.arch != .wasm32) {
        _ = gladLoadGL(@ptrCast(*const GLADloadproc, @alignCast(@alignOf(GLADloadproc), p)));
    }

    g_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    g_allocator = g_gpa.allocator();

    // init microui
    var ctx = g_allocator.create(zigmui.Context) catch unreachable;
    g_ctx = ctx;
    ctx.* = zigmui.Context{};
    var style = &ctx.command_drawer.style;
    style.text_width_callback = &atlas.zigmui_width;
    style.text_height_callback = &atlas.zigmui_height;
}

export fn ENGINE_deinit() callconv(.C) void {
    if (g_ctx) |ctx| {
        g_allocator.destroy(ctx);
    }
    std.debug.assert(!g_gpa.deinit());
}

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

fn ptrAlignCast(comptime T: type, p: *const anyopaque) T {
    @setRuntimeSafety(false);
    const info = @typeInfo(T);
    return @ptrCast(T, @alignCast(info.Pointer.alignment, p));
}

export fn ENGINE_render(width: c_int, height: c_int) callconv(.C) zigmui.CURSOR_SHAPE {
    const ctx = g_ctx orelse {
        return .ARROW;
    };

    ctx.begin();
    if (zigmui.widgets.begin_window(ctx, "Style Editor", .{ .x = 350, .y = 250, .w = 300, .h = 240 }, .NONE)) {
        // const sw = @floatToInt(i32, @intToFloat(f32, ctx.container.current_container().body.w) * 0.14);
        // {
        //     const widths = [_]i32{ 80, sw, sw, sw, sw, -1 };
        //     ctx.layout.stack.back().row(&widths, 0);
        // }
        // const style = &ctx.command_drawer.style;
        // for (colors) |color, i| {
        //     zigmui.widgets.label(ctx, color.label);
        //     const style_color = &style.colors[i];
        //     _ = uint8_slider(ctx, &style_color.r, 0, 255);
        //     _ = uint8_slider(ctx, &style_color.g, 0, 255);
        //     _ = uint8_slider(ctx, &style_color.b, 0, 255);
        //     _ = uint8_slider(ctx, &style_color.a, 0, 255);
        //     ctx.command_drawer.draw_rect(ctx.layout.stack.back().next(style), style.colors[i]);
        // }
        zigmui.widgets.end_window(ctx);
    }

    var command: zigmui.RenderFrame = undefined;
    try ctx.end(&command);

    gl.viewport(0, 0, width, height);
    gl.clearColor(0.2, 0.3, 0.4, 1.0);
    gl.clear(gl.GL_COLOR_BUFFER_BIT);

    // for (command.slice()) |it| {
    //     var p = command.get(it.head);
    //     var end = command.get(it.tail);
    //     while (p != end) {
    //         const command_type = @intToEnum(zigmui.COMMAND, ptrAlignCast(*const c_int, p).*);
    //         switch (command_type) {
    //             .CLIP => {
    //                 const cmd = ptrAlignCast(*const zigmui.ClipCommand, p + 4);
    //                 r.set_clip_rect(cmd.rect);
    //                 p += (4 + @sizeOf(zigmui.ClipCommand));
    //             },
    //             .RECT => {
    //                 const cmd = ptrAlignCast(*const zigmui.RectCommand, p + 4);
    //                 r.draw_rect(cmd.rect, cmd.color);
    //                 p += (4 + @sizeOf(zigmui.RectCommand));
    //             },
    //             .TEXT => {
    //                 const cmd = ptrAlignCast(*const zigmui.TextCommand, p + 4);
    //                 const begin = 4 + @sizeOf(zigmui.TextCommand);
    //                 const text = p[begin .. begin + cmd.length];
    //                 r.draw_text(text, cmd.pos, cmd.color);
    //                 p += (4 + @sizeOf(zigmui.TextCommand) + cmd.length);
    //             },
    //             .ICON => {
    //                 const cmd = ptrAlignCast(*const zigmui.IconCommand, p + 4);
    //                 r.draw_icon(@intCast(u32, cmd.id), cmd.rect, cmd.color);
    //                 p += (4 + @sizeOf(zigmui.IconCommand));
    //             },
    //         }
    //     }
    // }

    return .ARROW;
}
