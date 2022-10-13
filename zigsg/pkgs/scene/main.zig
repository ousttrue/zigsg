const std = @import("std");

pub fn load_path(path: []const u8) void {
    std.debug.print("{s}", .{path});
}

pub fn render() void {}
