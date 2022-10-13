const std = @import("std");
const vec = @import("./vec.zig");
const rotation = @import("./rotation.zig");
const ray_intersection = @import("./ray_intersection.zig");
const transformation = @import("./transformation.zig");
const util = @import("./util.zig");
const @"*" = util.@"*";
const Rotation = rotation.Rotation;

pub const Projection = struct {
    const Self = @This();

    fovy: f32 = std.math.pi * (60.0 / 180.0),
    near: f32 = 0.1,
    far: f32 = 100.0,
    width: i32 = 1,
    height: i32 = 1,

    pub fn resize(self: *Self, width: i32, height: i32) void {
        self.width = width;
        self.height = height;
    }

    pub fn getAspectRatio(self: Self) f32 {
        return @intToFloat(f32, self.width) / @intToFloat(f32, self.height);
    }

    pub fn getMatrix(self: *const Self) transformation.Mat4 {
        return transformation.Mat4.perspective(self.fovy, self.getAspectRatio(), self.near, self.far);
    }
};

pub const View = struct {
    const Self = @This();

    gaze: vec.Vec3 = vec.Vec3.values(0, 0, 0),
    rotation: Rotation = .identity,
    shift: vec.Vec3 = vec.Vec3.values(0, 0, -5),

    pub fn getViewMatrix(self: Self) transformation.Mat4 {
        const g = transformation.Mat4.translate(self.gaze.inversed());
        const r = transformation.Mat4.rotate(self.rotation);
        const t = transformation.Mat4.translate(self.shift);
        return @"*"(g, @"*"(r, t));
    }

    pub fn getTransformMatrix(self: Self) transformation.Mat4 {
        const inverse = self.rotation.inversed();
        const r = transformation.Mat4.rotate(inverse);
        const t = transformation.Mat4.translate(self.shift.inversed());
        return @"*"(t, r);
    }
};

pub const Camera = struct {
    const Self = @This();

    projection: Projection = .{},
    view: View = .{},

    pub fn getViewProjectionMatrix(self: *const Self) transformation.Mat4 {
        const p = self.projection.getMatrix();
        const v = self.view.getViewMatrix();
        return @"*"(v, p);
    }

    pub fn getRay(self: Self, x: i32, y: i32) ray_intersection.Ray {
        const inv = self.view.rotation.toMat3().transposed();
        return ray_intersection.Ray.createFromScreen(
            @intToFloat(f32, x),
            @intToFloat(f32, y),
            @intToFloat(f32, self.projection.width),
            @intToFloat(f32, self.projection.height),
            inv.apply(self.view.shift.inversed()),
            inv,
            self.projection.fovy,
            self.projection.getAspectRatio(),
        );
    }
};

test "Camera" {
    var c = Camera{};
    c.projection.resize(2, 2);

    const m = c.view.getTransformMatrix();
    try std.testing.expectEqual(vec.Vec4.values(0, 0, 5, 1), m._3);

    const ray = c.getRay(1, 1);
    try std.testing.expectEqual(vec.Vec3.values(0, 0, 5), ray.origin);
    try std.testing.expectEqual(vec.Vec3.values(0, 0, -1), ray.dir);
}
