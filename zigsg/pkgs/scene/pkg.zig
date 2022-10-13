const std = @import("std");
const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;
const LibExeObjStep = std.build.LibExeObjStep;

pub fn addTo(allocator: std.mem.Allocator, exe: *LibExeObjStep, relativePath: []const u8, dependencies: ?[]const Pkg) void {
    exe.addPackage(Pkg{
        .name = "scene",
        .source = FileSource{ .path = std.fmt.allocPrint(allocator, "{s}{s}", .{ relativePath, "/src/main.zig" }) catch @panic("allocPrint") },
        .dependencies = dependencies,
    });
}
