const std = @import("std");

const zigmui_pkg = std.build.Pkg{
    .name = "zigmui",
    .source = .{ .path = "pkgs/microui/zig_renderer/pkgs/zigmui/main.zig" },
};

const gl_pkg = std.build.Pkg{
    .name = "gl",
    .source = .{ .path = "pkgs/microui/zig_renderer/pkgs/gl_placeholder/main.zig" },
};

const atlas_pkg = std.build.Pkg{
    .name = "atlas",
    .source = .{ .path = "pkgs/microui/zig_renderer/pkgs/atlas/main.zig" },
};

const zigmui_impl_gl_pkg = std.build.Pkg{
    .name = "zigmui_impl_gl",
    .source = .{ .path = "pkgs/microui/zig_renderer/pkgs/zigmui_impl_gl/main.zig" },
    .dependencies = &.{ zigmui_pkg, gl_pkg, atlas_pkg },
};

const zigla_pkg = std.build.Pkg{
    .name = "zigla",
    .source = .{ .path = "pkgs/zigla/src/main.zig" },
};

const glo_pkg = std.build.Pkg{
    .name = "glo",
    .source = .{ .path = "pkgs/glo/src/main.zig" },
    .dependencies = &.{gl_pkg},
};

const scene_pkg = std.build.Pkg{
    .name = "scene",
    .source = .{ .path = "pkgs/scene/src/main.zig" },
    .dependencies = &.{ zigla_pkg, glo_pkg },
};

const GLFW_BASE = "../_external/glfw";

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    // const lib = b.addStaticLibrary("zigsg", "src/main.zig");
    const lib = b.addSharedLibrary("zigsg", "src/main.zig", .unversioned);
    lib.setBuildMode(mode);
    lib.setTarget(target);
    lib.addPackage(zigmui_pkg);
    lib.addPackage(gl_pkg);
    lib.addPackage(atlas_pkg);
    lib.addPackage(zigmui_impl_gl_pkg);
    lib.addPackage(scene_pkg);
    if (target.cpu_arch == std.Target.Cpu.Arch.wasm32) {
        lib.stack_size = 6 * 1024 * 1024;
    } else {
        lib.linkLibC();
        lib.linkLibCpp();
        lib.addIncludePath(GLFW_BASE ++ "/deps");
        lib.addCSourceFile(GLFW_BASE ++ "/deps/glad_gl.c", &.{});
        lib.addCSourceFile("pkgs/microui/zig_renderer/pkgs/gl_placeholder/gl_placeholder.c", &.{"-Wno-int-conversion"});
    }
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
