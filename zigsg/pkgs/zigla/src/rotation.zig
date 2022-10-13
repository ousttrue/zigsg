const std = @import("std");
const vec = @import("./vec.zig");
const util = @import("./util.zig");
const Vec3 = vec.Vec3;
const sign = util.sign;

// pub const Axis = union(enum) {
//     const Self = @This();

//     x,
//     y,
//     z,
//     vec3: Vec3,

//     pub fn toVec3(self: Self) Vec3 {
//         return switch (self) {
//             .x => Vec3.values(1, 0, 0),
//             .y => Vec3.values(0, 1, 0),
//             .z => Vec3.values(0, 0, 1),
//             .vec3 => |v| v,
//         };
//     }
// };

// pub const AngleAxis = struct {
//     const Self = @This();
//     angle: f32,
//     axis: Axis,
//     pub fn init(angle: f32, axis: Vec3) Self {
//         return Self{
//             .angle = angle,
//             .axis = .{ .vec3 = axis },
//         };
//     }
// };

/// mat3 for rotation. without scale
pub const Mat3 = struct {
    const Self = @This();

    _0: Vec3 = Vec3.values(1, 0, 0),
    _1: Vec3 = Vec3.values(0, 1, 0),
    _2: Vec3 = Vec3.values(0, 0, 1),

    pub fn values(_00: f32, _01: f32, _02: f32, _10: f32, _11: f32, _12: f32, _20: f32, _21: f32, _22: f32) Self {
        return .{
            ._0 = Vec3.values(_00, _01, _02),
            ._1 = Vec3.values(_10, _11, _12),
            ._2 = Vec3.values(_20, _21, _22),
        };
    }

    pub fn rows(_0: Vec3, _1: Vec3, _2: Vec3) Self {
        return .{ ._0 = _0, ._1 = _1, ._2 = _2 };
    }

    pub fn scale(s: Vec3) Self {
        return .{
            ._0 = Vec3.values(s.x, 0, 0),
            ._1 = Vec3.values(0, s.y, 0),
            ._2 = Vec3.values(0, 0, s.z),
        };
    }

    pub fn angleAxis(angle: f32, a: Vec3) Self {
        const c = std.math.cos(angle);
        const s = std.math.sin(angle);
        const _00 = c + a.x * a.x * (1 - c);
        const _10 = a.x * a.y * (1 - c) - a.z * s;
        const _20 = a.x * a.z * (1 - c) + a.y * s;
        const _01 = a.x * a.y * (1 - c) + a.z * s;
        const _11 = c + a.y * a.y * (1 - c);
        const _21 = a.y * a.z * (1 - c) - a.x * s;
        const _02 = a.x * a.z * (1 - c) - a.y * s;
        const _12 = a.y * a.z * (1 - c) + a.x * s;
        const _22 = c + a.z * a.z * (1 - c);
        return Self.rows(
            Vec3.values(_00, _01, _02),
            Vec3.values(_10, _11, _12),
            Vec3.values(_20, _21, _22),
        );
    }

    pub fn quaternion(q: Quaternion) Self {
        const _00 = 1 - 2 * q.y * q.y - 2 * q.z * q.z;
        const _10 = 2 * q.x * q.y - 2 * q.w * q.z;
        const _20 = 2 * q.z * q.x + 2 * q.w * q.y;
        const _01 = 2 * q.x * q.y + 2 * q.w * q.z;
        const _11 = 1 - 2 * q.z * q.z - 2 * q.x * q.x;
        const _21 = 2 * q.y * q.z - 2 * q.w * q.x;
        const _02 = 2 * q.z * q.x - 2 * q.w * q.y;
        const _12 = 2 * q.y * q.z + 2 * q.w * q.x;
        const _22 = 1 - 2 * q.x * q.x - 2 * q.y * q.y;
        return Self.rows(
            Vec3.values(_00, _01, _02),
            Vec3.values(_10, _11, _12),
            Vec3.values(_20, _21, _22),
        );
    }

    pub fn getRow(self: Self, comptime row: usize) Vec3 {
        return switch (row) {
            0 => self._0,
            1 => self._1,
            2 => self._2,
            else => unreachable,
        };
    }

    /// http://www.info.hiroshima-cu.ac.jp/~miyazaki/knowledge/tech0052.html
    pub fn toQuaternion(self: Self) Quaternion {
        const _00 = self._0.x;
        const _01 = self._0.y;
        const _02 = self._0.z;
        const _10 = self._1.x;
        const _11 = self._1.y;
        const _12 = self._1.z;
        const _20 = self._2.x;
        const _21 = self._2.y;
        const _22 = self._2.z;

        var q0 = (_00 + _11 + _22 + 1.0) / 4.0;
        var q1 = (_00 - _11 - _22 + 1.0) / 4.0;
        var q2 = (-_00 + _11 - _22 + 1.0) / 4.0;
        var q3 = (-_00 - _11 + _22 + 1.0) / 4.0;
        if (q0 < 0.0) q0 = 0.0;
        if (q1 < 0.0) q1 = 0.0;
        if (q2 < 0.0) q2 = 0.0;
        if (q3 < 0.0) q3 = 0.0;
        q0 = std.math.sqrt(q0);
        q1 = std.math.sqrt(q1);
        q2 = std.math.sqrt(q2);
        q3 = std.math.sqrt(q3);
        if (q0 >= q1 and q0 >= q2 and q0 >= q3) {
            // q0 *= 1.0;
            q1 *= sign(_12 - _21);
            q2 *= sign(_20 - _02);
            q3 *= sign(_01 - _10);
        } else if (q1 >= q0 and q1 >= q2 and q1 >= q3) {
            q0 *= sign(_12 - _21);
            // q1 *= 1.0;
            q2 *= sign(_01 + _10);
            q3 *= sign(_20 + _02);
        } else if (q2 >= q0 and q2 >= q1 and q2 >= q3) {
            q0 *= sign(_20 - _02);
            q1 *= sign(_01 + _10);
            // q2 *= 1.0;
            q3 *= sign(_12 + _21);
        } else if (q3 >= q0 and q3 >= q1 and q3 >= q2) {
            q0 *= sign(_01 - _10);
            q1 *= sign(_02 + _20);
            q2 *= sign(_12 + _21);
            q3 *= 1.0;
        } else {
            unreachable;
        }
        const r = 1.0 / util.norm(q0, q1, q2, q3);
        q0 *= r;
        q1 *= r;
        q2 *= r;
        q3 *= r;
        return Quaternion{ .x = q1, .y = q2, .z = q3, .w = q0 };
    }

    pub fn toArray(self: *Self) [9]f32 {
        return @ptrCast([*]f32, &self._0.x)[0..9].*;
    }
    pub fn col0(self: Self) Vec3 {
        return Vec3.values(self._0.x, self._1.x, self._2.x);
    }
    pub fn col1(self: Self) Vec3 {
        return Vec3.values(self._0.y, self._1.y, self._2.y);
    }
    pub fn col2(self: Self) Vec3 {
        return Vec3.values(self._0.z, self._1.z, self._2.z);
    }

    pub fn transposed(self: Self) Self {
        return Mat3.rows(
            self.col0(),
            self.col1(),
            self.col2(),
        );
    }

    pub fn det(self: Self) f32 {
        return (self._0.x * self._1.y * self._2.z + self._0.y * self._1.z * self._2.x + self._0.z * self._1.x + self._2.y) - (self._0.x * self._1.z * self._2.y + self._0.y * self._1.x * self._2.z + self._0.z * self._1.y * self._2.x);
    }

    pub fn normalized(self: Self) Self {
        var copy = self;
        copy.normalize();
        return copy;
    }

    pub fn normalize(self: *Self) void {
        const d = self.det();
        const f = 1.0 / d;
        const s = Mat3.values(
            f,
            0,
            0,
            0,
            f,
            0,
            0,
            0,
            f,
        );
        self.* = self.mul(s);
    }

    pub fn mul(self: Self, rhs: Self) Self {
        return Self.rows(
            Vec3.values(self._0.dot(rhs.col0()), self._0.dot(rhs.col1()), self._0.dot(rhs.col2())),
            Vec3.values(self._1.dot(rhs.col0()), self._1.dot(rhs.col1()), self._1.dot(rhs.col2())),
            Vec3.values(self._2.dot(rhs.col0()), self._2.dot(rhs.col1()), self._2.dot(rhs.col2())),
        );
    }

    ///          [m00, m01, m02]
    /// [x, y, z][m10, m11, m12] => [x', y', z']
    ///          [m20, m21, m22]
    pub fn apply(self: Self, v: Vec3) Vec3 {
        return Vec3.values(
            v.dot(self.col0()),
            v.dot(self.col1()),
            v.dot(self.col2()),
        );
    }
};

test "Mat3" {
    const m = Mat3{};
    try std.testing.expectEqual(@as(f32, 1.0), m.det());
    var axis = Vec3.values(1, 2, 3);
    axis.normalize();
    const angle = std.math.pi * 25.0 / 180.0;
    const q = Quaternion.angleAxis(angle, axis);
    try std.testing.expect(util.nearlyEqual(@as(f32, 1e-5), 9, Mat3.quaternion(q).toArray(), Mat3.angleAxis(angle, axis).toArray()));
}

pub const Quaternion = packed struct {
    const Self = @This();
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub fn angleAxis(angle: f32, axis: Vec3) Self {
        const half = angle / 2;
        const c = std.math.cos(half);
        const s = std.math.sin(half);
        return .{
            .x = axis.x * s,
            .y = axis.y * s,
            .z = axis.z * s,
            .w = c,
        };
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

    pub fn inversed(self: Self) Self {
        return .{ .x = -self.x, .y = -self.y, .z = -self.z, .w = self.w };
    }

    pub fn rotate(self: Self, v: Vec3) Vec3 {
        return Mat3.quaternion(self).apply(v);
    }

    pub fn mul(self: Self, rhs: Self) Self {
        const lv = Vec3{ .x = self.x, .y = self.y, .z = self.z };
        const rv = Vec3{ .x = rhs.x, .y = rhs.y, .z = rhs.z };
        const v = lv.mul(rhs.w).add(rv.mul(self.w)).add(lv.cross(rv));
        return .{
            .x = v.x,
            .y = v.y,
            .z = v.z,
            .w = self.w * rhs.w - lv.dot(rv),
        };
    }
};

test "Quaternion" {
    const q = Quaternion{};
    try std.testing.expectEqual(q, q.mul(q));

    const m = Mat3.quaternion(q);
    const qq = m.toQuaternion();
    try std.testing.expectEqual(q, qq);
    try std.testing.expectEqual(Quaternion{ .x = 0, .y = 0, .z = 0, .w = 1 }, qq);
}

/// TODO: euler angles
pub const Rotation = union(enum) {
    const Self = @This();

    identity,
    mat3: Mat3,
    quaternion: Quaternion,

    pub fn angleAxis(angle: f32, axis: Vec3) Self {
        return .{
            .quaternion = Quaternion.angleAxis(angle, axis),
        };
    }

    pub fn toMat3(self: Self) Mat3 {
        return switch (self) {
            .identity => .{},
            .mat3 => |m| m,
            .quaternion => |q| Mat3.quaternion(q),
        };
    }

    pub fn inversed(self: Self) Self {
        return switch (self) {
            .identity => .identity,
            .mat3 => |m| .{ .mat3 = m.transposed() },
            .quaternion => |q| .{ .quaternion = q.inversed() },
        };
    }

    pub fn rotate(self: Self, v: Vec3) Vec3 {
        return switch (self) {
            .identity => v,
            .mat3 => |m| m.apply(v),
            .quaternion => |q| q.rotate(v),
        };
    }

    pub fn mul(self: Self, rhs: Self) Self {
        switch (self) {
            .identity => return rhs,
            .mat3 => |l_mat3| {
                switch (rhs) {
                    .identity => return self,
                    .mat3 => |r_mat3| {
                        var m = l_mat3.mul(r_mat3);
                        m.normalize();
                        return .{ .mat3 = m };
                    },
                    .quaternion => |r_q| {
                        const r_mat3 = Mat3.quaternion(r_q);
                        var m = l_mat3.mul(r_mat3);
                        m.normalize();
                        return .{ .mat3 = m };
                    },
                }
            },
            .quaternion => |l_q| {
                switch (rhs) {
                    .identity => return self,
                    .mat3 => |r_mat3| {
                        const r_q = r_mat3.toQuaternion();
                        var q = l_q.mul(r_q);
                        q.normalize();
                        return .{ .quaternion = q };
                    },
                    .quaternion => |r_q| {
                        var q = l_q.mul(r_q);
                        q.normalize();
                        return .{ .quaternion = q };
                    },
                }
            },
        }
    }
};
