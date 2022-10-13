const std = @import("std");
const util = @import("./util.zig");
const @"+" = util.@"+";

pub const Vec2 = struct {
    const Self = @This();
    x: f32,
    y: f32,
    pub fn values(x: f32, y: f32) Self {
        return .{ .x = x, .y = y };
    }
    pub fn inversed(self: Self) Self {
        return .{ .x = -self.x, .y = -self.y };
    }
    pub fn dot(self: Self, rhs: Self) f32 {
        return self.x * rhs.x + self.y * rhs.y;
    }
    pub fn sub(self: Self, rhs: Self) Vec2 {
        return .{ .x = self.x - rhs.x, .y = self.y - rhs.y };
    }
    pub fn normalize(self: *Self) void {
        const sqnorm = self.dot(self.*);
        const factor = 1.0 / std.math.sqrt(sqnorm);
        self.x *= factor;
        self.y *= factor;
    }
    pub fn normalized(self: Self) Self {
        var copy = self;
        copy.normalize();
        return copy;
    }
};

pub const Vec3 = packed struct {
    const Self = @This();
    x: f32,
    y: f32,
    z: f32,
    pub fn values(x: f32, y: f32, z: f32) Self {
        return .{ .x = x, .y = y, .z = z };
    }
    pub fn scalar(n: f32) Self {
        return .{ .x = n, .y = n, .z = n };
    }
    pub fn vec2(v: Vec2, z: f32) Vec3 {
        return .{ .x = v.x, .y = v.y, .z = z };
    }
    pub fn toArray(self: *Self) [3]f32 {
        return (@ptrCast([*]f32, &self.x))[0..3].*;
    }
    pub fn toVec2(self: Self) Vec2 {
        return .{ .x = self.x, .y = self.y };
    }
    pub fn const_array(self: *const Self) [3]f32 {
        return (@ptrCast([*]const f32, &self.x))[0..3].*;
    }
    pub fn inversed(self: Self) Self {
        return .{ .x = -self.x, .y = -self.y, .z = -self.z };
    }
    pub fn dot(self: Self, rhs: Self) f32 {
        return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z;
    }
    pub fn mul(self: Self, n: f32) Vec3 {
        return .{ .x = self.x * n, .y = self.y * n, .z = self.z * n };
    }
    pub fn add(self: Self, rhs: Self) Vec3 {
        return .{ .x = self.x + rhs.x, .y = self.y + rhs.y, .z = self.z + rhs.z };
    }
    pub fn sub(self: Self, rhs: Self) Vec3 {
        return .{ .x = self.x - rhs.x, .y = self.y - rhs.y, .z = self.z - rhs.z };
    }

    pub fn cross(self: Self, rhs: Vec3) Vec3 {
        return .{
            .x = self.y * rhs.z - self.z * rhs.y,
            .y = self.z * rhs.x - self.x * rhs.z,
            .z = self.x * rhs.y - self.y * rhs.x,
        };
    }
    pub fn normalize(self: *Self) void {
        const sqnorm = self.dot(self.*);
        const len = std.math.sqrt(sqnorm);
        const factor = 1.0 / len;
        self.x *= factor;
        self.y *= factor;
        self.z *= factor;
    }
    pub fn normalized(self: Self) Self {
        var copy = self;
        copy.normalize();
        return copy;
    }
};

test "Vec3" {
    const v1 = Vec3.values(1, 2, 3);
    try std.testing.expectEqual(@as(f32, 14.0), v1.dot(v1));
    try std.testing.expectEqual(Vec3.values(2, 4, 6), v1.mul(2.0));
    try std.testing.expectEqual(Vec3.values(2, 4, 6), @"+"(v1, v1));
    try std.testing.expectEqual(Vec3.values(0, 0, 1), Vec3.values(1, 0, 0).cross(Vec3.values(0, 1, 0)));
    try std.testing.expectEqual(Vec3.values(1, 0, 0), Vec3.values(2, 0, 0).normalized());
}

pub const Vec4 = packed struct {
    const Self = @This();
    x: f32,
    y: f32,
    z: f32,
    w: f32,
    pub fn values(x: f32, y: f32, z: f32, w: f32) Self {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }
    pub fn vec3(v: Vec3, w: f32) Vec4 {
        return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
    }
    pub fn toVec3(self: Self) Vec3 {
        return .{ .x = self.x, .y = self.y, .z = self.z };
    }
    pub fn dot(self: Self, rhs: Vec4) f32 {
        return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z + self.w * rhs.w;
    }
    pub fn normalize(self: *Self) void {
        const sqnorm = self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w;
        const factor = 1 / std.math.sqrt(sqnorm);
        self.x *= factor;
        self.y *= factor;
        self.z *= factor;
        self.w *= factor;
    }
    pub fn normalized(self: Self) Self {
        var copy = self;
        copy.normalize();
        return copy;
    }
};
