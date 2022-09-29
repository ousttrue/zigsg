const std = @import("std");

const zigmui_pkg = std.build.Pkg{
    .name = "zigmui",
    .source = .{ .path = "pkgs/microui/zig_renderer/pkgs/zigmui/main.zig" },
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
    if (target.cpu_arch == std.Target.Cpu.Arch.wasm32) {
        lib.stack_size = 6 * 1024 * 1024;
    } else {
        lib.linkLibC();
        lib.linkLibCpp();
        lib.addIncludePath(GLFW_BASE ++ "/deps");
        lib.addCSourceFile(GLFW_BASE ++ "/deps/glad_gl.c", &.{});
        lib.addCSourceFile("pkgs/microui/zig_renderer/src/glad_placeholders.c", &.{"-Wno-int-conversion"});
    }
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
