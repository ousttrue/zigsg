const std = @import("std");
const builtin = @import("builtin");
const zigmui = @import("zigmui");
const atlas = @import("atlas");
const gl = @import("gl");
const Renderer = @import("zigmui_impl_gl").Renderer;
const scene = @import("scene");

var g_ctx: ?*zigmui.Context = null;
var g_gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var g_allocator: std.mem.Allocator = undefined;
var g_renderer: ?Renderer = null;
var g_scene: ?*scene.Scene = null;

export fn ENGINE_init(p: *const anyopaque) callconv(.C) void {
    g_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    g_allocator = g_gpa.allocator();

    // init microui
    var ctx = g_allocator.create(zigmui.Context) catch unreachable;
    g_ctx = ctx;
    ctx.* = zigmui.Context{};
    var style = &ctx.command_drawer.style;
    style.text_width_callback = &atlas.zigmui_width;
    style.text_height_callback = &atlas.zigmui_height;

    g_renderer = Renderer.init(p, atlas.width, atlas.height, atlas.data);

    // load model
    var pScene = scene.Scene.new(g_allocator);
    g_scene = pScene;
    var it = std.process.ArgIterator.initWithAllocator(g_allocator) catch unreachable;
    defer it.deinit();
    // arg0
    _ = it.next();
    // arg1
    if (it.next()) |arg| {
        if(scene.Model.load(g_allocator, arg))|model|
        {
            pScene.model = model;
        }
    }
}

export fn ENGINE_deinit() callconv(.C) void {
    if (g_ctx) |ctx| {
        g_allocator.destroy(ctx);
    }
    std.debug.assert(!g_gpa.deinit());
}

export fn ENGINE_mousemove(x: c_int, y: c_int) callconv(.C) void {
    const ctx = g_ctx orelse return;
    ctx.input.set_mousemove(x, y);
}
export fn ENGINE_mousebutton_press(button: c_int) callconv(.C) void {
    const ctx = g_ctx orelse return;
    ctx.input.set_mousedown(switch (button) {
        0 => zigmui.Input.MOUSE_BUTTON.LEFT,
        1 => zigmui.Input.MOUSE_BUTTON.RIGHT,
        2 => zigmui.Input.MOUSE_BUTTON.MIDDLE,
        else => return,
    });
}
export fn ENGINE_mousebutton_release(button: c_int) callconv(.C) void {
    const ctx = g_ctx orelse return;
    ctx.input.set_mouseup(switch (button) {
        0 => zigmui.Input.MOUSE_BUTTON.LEFT,
        1 => zigmui.Input.MOUSE_BUTTON.RIGHT,
        2 => zigmui.Input.MOUSE_BUTTON.MIDDLE,
        else => return,
    });
}
export fn ENGINE_mousewheel(x: c_int, y: c_int) callconv(.C) void {
    const ctx = g_ctx orelse return;
    ctx.input.set_scroll(x, y);
}

fn keyMap(ch: c_int) zigmui.Input.KEY {
    return switch (ch) {
        // GLFW_KEY_LEFT_SHIFT
        340 => .SHIFT,
        // GLFW_KEY_RIGHT_SHIFT
        344 => .SHIFT,
        // GLFW_KEY_LEFT_CONTROL
        341 => .CTRL,
        // GLFW_KEY_RIGHT_CONTROL
        345 => .CTRL,
        // GLFW_KEY_LEFT_ALT
        342 => .ALT,
        // GLFW_KEY_RIGHT_ALT
        346 => .ALT,
        // GLFW_KEY_ENTER
        257 => .RETURN,
        // GLFW_KEY_BACKSPACE
        259 => .BACKSPACE,
        else => .NONE,
    };
}
export fn ENGINE_key_press(ch: c_int) callconv(.C) void {
    const ctx = g_ctx orelse return;
    ctx.input.set_keydown(keyMap(ch));
}
export fn ENGINE_key_release(ch: c_int) callconv(.C) void {
    const ctx = g_ctx orelse return;
    ctx.input.set_keyup(keyMap(ch));
}
export fn ENGINE_unicode(cp: c_uint) callconv(.C) void {
    const ctx = g_ctx orelse return;
    var buf: [4]u8 = undefined;
    if (std.unicode.utf8Encode(@intCast(u21, cp), &buf)) |len| {
        ctx.input.push_text(buf[0..len]);
    } else |_| {}
}

export fn ENGINE_render(width: c_int, height: c_int) callconv(.C) zigmui.CURSOR_SHAPE {
    const ctx = g_ctx orelse {
        return .ARROW;
    };

    ctx.begin();
    if (zigmui.widgets.begin_window(ctx, "scene", .{ .x = 350, .y = 250, .w = 300, .h = 240 }, .NONE)) {
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

    // render scene

    if (g_renderer) |*r| {
        r.redner_zigmui(width, height, command);
        r.flush();
    }

    return command.cursor_shape;
}
