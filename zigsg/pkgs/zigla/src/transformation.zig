const std = @import("std");
const vec = @import("./vec.zig");
const rotation = @import("./rotation.zig");
const Vec3 = vec.Vec3;
const Vec4 = vec.Vec4;
const util = @import("./util.zig");

pub const Mat4 = packed struct {
    const Self = @This();

    // rows
    _0: Vec4 = Vec4.values(1, 0, 0, 0),
    _1: Vec4 = Vec4.values(0, 1, 0, 0),
    _2: Vec4 = Vec4.values(0, 0, 1, 0),
    _3: Vec4 = Vec4.values(0, 0, 0, 1),

    pub fn array(a: [16]f32) Self {
        return .{
            ._0 = Vec4.values(a[0], a[1], a[2], a[3]),
            ._1 = Vec4.values(a[4], a[5], a[6], a[7]),
            ._2 = Vec4.values(a[8], a[9], a[10], a[11]),
            ._3 = Vec4.values(a[12], a[13], a[14], a[15]),
        };
    }

    pub fn values(_00: f32, _01: f32, _02: f32, _03: f32, _10: f32, _11: f32, _12: f32, _13: f32, _20: f32, _21: f32, _22: f32, _23: f32, _30: f32, _31: f32, _32: f32, _33: f32) Mat4 {
        return .{
            ._0 = Vec4.values(_00, _01, _02, _03),
            ._1 = Vec4.values(_10, _11, _12, _13),
            ._2 = Vec4.values(_20, _21, _22, _23),
            ._3 = Vec4.values(_30, _31, _32, _33),
        };
    }

    pub fn rows(_0: Vec4, _1: Vec4, _2: Vec4, _3: Vec4) Mat4 {
        return .{
            ._0 = _0,
            ._1 = _1,
            ._2 = _2,
            ._3 = _3,
        };
    }

    pub fn getRow(self: Self, comptime row: usize) Vec4 {
        return switch (row) {
            0 => self._0,
            1 => self._1,
            2 => self._2,
            3 => self._3,
            else => unreachable,
        };
    }

    pub fn toMat3(self: Self) rotation.Mat3 {
        return rotation.Mat3.rows(
            self._0.toVec3(),
            self._1.toVec3(),
            self._2.toVec3(),
        );
    }

    pub fn frustum(b: f32, t: f32, l: f32, r: f32, n: f32, f: f32) Self {
        // set OpenGL perspective projection matrix
        return Self.rows(
            Vec4.values(2 * n / (r - l), 0, 0, 0),
            Vec4.values(0, 2 * n / (t - b), 0, 0),
            Vec4.values((r + l) / (r - l), (t + b) / (t - b), -(f + n) / (f - n), -1),
            Vec4.values(0, 0, -2 * f * n / (f - n), 0),
        );
    }

    pub fn perspective(fov: f32, aspect: f32, n: f32, f: f32) Self {
        const scale = std.math.tan(fov / 2) * n;
        const r = aspect * scale;
        const l = -r;
        const t = scale;
        const b = -t;
        return frustum(b, t, l, r, n, f);
    }

    pub fn translate(t: Vec3) Self {
        return Self.rows(
            Vec4.values(1, 0, 0, 0),
            Vec4.values(0, 1, 0, 0),
            Vec4.values(0, 0, 1, 0),
            Vec4.vec3(t, 1),
        );
    }

    pub fn mat3(m: rotation.Mat3) Mat4 {
        return Self.rows(
            Vec4.vec3(m._0, 0),
            Vec4.vec3(m._1, 0),
            Vec4.vec3(m._2, 0),
            Vec4.values(0, 0, 0, 1),
        );
    }

    pub fn rotate(r: rotation.Rotation) Mat4 {
        return Self.mat3(r.toMat3());
    }

    pub fn col0(self: Self) Vec4 {
        return Vec4.values(self._0.x, self._1.x, self._2.x, self._3.x);
    }
    pub fn col1(self: Self) Vec4 {
        return Vec4.values(self._0.y, self._1.y, self._2.y, self._3.y);
    }
    pub fn col2(self: Self) Vec4 {
        return Vec4.values(self._0.z, self._1.z, self._2.z, self._3.z);
    }
    pub fn col3(self: Self) Vec4 {
        return Vec4.values(self._0.w, self._1.w, self._2.w, self._3.w);
    }

    ///             [m00, m01, m02, m03]
    ///             [m10, m11, m12, m13]
    /// [x, y, z, w][m20, m21, m22, m23]
    ///             [m30, m31, m32, m33]
    pub fn apply(self: Self, v: Vec4) Vec4 {
        return Vec4.values(
            v.dot(self.col0()),
            v.dot(self.col1()),
            v.dot(self.col2()),
            v.dot(self.col3()),
        );
    }
    // pub fn mul(self: Self, rhs: Mat4) Self {
    //     return Self.init(
    //         self.dot(rhs.col0()),
    //         self.dot(rhs.col0()),
    //         self.dot(rhs.col0()),
    //         self.dot(rhs.col0()),
    //     );
    // }

    pub fn applyVec3(self: Self, v: Vec3, w: f32) Vec3 {
        const v4 = self.apply(Vec4.vec3(v, w));
        return v4.toVec3();
    }

    pub fn mul(self: Self, rhs: Self) Self {
        return Self.rows(
            Vec4.values(
                self._0.dot(rhs.col0()),
                self._0.dot(rhs.col1()),
                self._0.dot(rhs.col2()),
                self._0.dot(rhs.col3()),
            ),
            Vec4.values(
                self._1.dot(rhs.col0()),
                self._1.dot(rhs.col1()),
                self._1.dot(rhs.col2()),
                self._1.dot(rhs.col3()),
            ),
            Vec4.values(
                self._2.dot(rhs.col0()),
                self._2.dot(rhs.col1()),
                self._2.dot(rhs.col2()),
                self._2.dot(rhs.col3()),
            ),
            Vec4.values(
                self._3.dot(rhs.col0()),
                self._3.dot(rhs.col1()),
                self._3.dot(rhs.col2()),
                self._3.dot(rhs.col3()),
            ),
        );
    }

    pub fn setTranslation(self: *Self, t: Vec3)void
    {
        self._3 = Vec4.vec3(t, 1);
    }
};

pub const Scaling = union(enum) {
    const Self = @This();

    identity,
    uniform: f32,
    vec3: Vec3,

    pub fn toMat3(self: Self) rotation.Mat3 {
        return switch (self) {
            .identity => .{},
            .uniform => |u| rotation.Mat3.scale(Vec3.values(u, u, u)),
            .vec3 => |v| rotation.Mat3.scale(v),
        };
    }
};

/// R|0
/// -+-
/// T|1
pub const TRS = struct {
    const Self = @This();

    translation: vec.Vec3 = vec.Vec3.scalar(0),
    rotation: rotation.Rotation = .identity,
    scale: Scaling = .identity,

    /// R * T * (Tinv * Rinv) = I
    /// Rinv        |
    /// ------------+---
    /// Tinv * Rinv | 1
    pub fn inversed(self: Self) Self {
        const inv = self.rotation.inversed();
        return .{
            .rotation = inv,
            .translation = inv.rotate(self.translation.inversed()),
        };
    }

    pub fn applyVec3(self: Self, v: vec.Vec3, w: f32) vec.Vec3 {
        if (w == 0) {
            return self.rotation.rotate(v);
        } else if (w == 1) {
            return self.rotation.rotate(v).add(self.translation);
        } else {
            unreachable;
        }
    }

    pub fn toMat4(self: Self) Mat4 {
        const r = self.rotation.toMat3();
        const s = self.scale.toMat3();
        var m = Mat4.mat3(r.mul(s));
        m.setTranslation(self.translation);
        return m;
    }
};

test "RigidBody inv" {
    const rb = TRS{};
    const inv = rb.inversed();
    try std.testing.expectEqual(rb, inv);
}

test "RigidBody" {
    const q = rotation.Quaternion.angleAxis(std.math.pi / 2.0, vec.Vec3.values(1, 0, 0));
    const t = vec.Vec3.values(0, 0, 1);
    const rb = TRS{ .rotation = .{ .quaternion = q }, .translation = t };
    const inv = rb.inversed();
    try std.testing.expect(util.nearlyEqual(@as(f32, 1e-5), 3, vec.Vec3.values(0, -1, 0).toArray(), inv.translation.const_array()));
}

pub const Transform = union(enum) {
    const Self = @This();

    identity,
    trs: TRS,
    mat4: Mat4,

    pub fn applyVec3(self: Self, v: Vec3, w: f32) Vec3 {
        return switch (self) {
            .identity => v,
            .trs => |trs| trs.applyVec3(v, w),
            .mat4 => |m| m.applyVec3(v, w),
        };
    }

    pub fn toMat4(self: Self) Mat4 {
        return switch (self) {
            .identity => .{},
            .trs => |trs| trs.toMat4(),
            .mat4 => |m| m,
        };
    }

    pub fn inversed(self: Self) Self {
        return switch (self) {
            .identity => .identity,
            .trs => |trs| Self{ .trs = trs.inversed() },
            .mat4 => |m| blk: {
                const q = m.toMat3().toQuaternion();
                const translation = m._3.toVec3();
                const trs = TRS{ .rotation = .{ .quaternion = q }, .translation = translation };
                break :blk Self{ .trs = trs.inversed() };
            },
        };
    }
};
