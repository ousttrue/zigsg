const std = @import("std");
const vec = @import("./vec.zig");
const rotation = @import("./rotation.zig");
const util = @import("./util.zig");
const @"-" = util.@"-";
const @"+" = util.@"+";
const @"*" = util.@"*";

pub const Ray = struct {
    const Self = @This();

    origin: vec.Vec3,
    dir: vec.Vec3,

    pub fn createFromScreen(x: f32, y: f32, w: f32, h: f32, t: vec.Vec3, r: rotation.Mat3, fov_y: f32, aspect: f32) Self {
        const half_fov = fov_y / 2.0;

        const xx = (x / w * 2 - 1);
        const yy = -(y / h * 2 - 1);
        // std.log.debug("({d:.2}, {d:.2}), ({d:.2}, {d:.2}), {d:.2}, {d:.2}", .{ x, y, w, h, xx, yy });

        var dir = r.apply(vec.Vec3.values(
            xx * std.math.tan(half_fov) * (aspect),
            yy * std.math.tan(half_fov),
            -1,
        ));
        // dir.normalize();

        // std.log.debug("({d:.2}, {d:.2}, {d:.2})", .{ dir.x, dir.y, dir.z });
        return .{ .origin = t, .dir = dir };
    }

    pub fn position(self: Self, t: f32) vec.Vec3 {
        return @"+"(self.origin, self.dir.mul(t));
    }
};

pub const Plain = struct {
    const Self = @This();
    n: vec.Vec3,
    d: f32,

    pub fn triangle(v0: vec.Vec3, v1: vec.Vec3, v2: vec.Vec3) Plain {
        const n = (@"-"(v1, v0)).cross(@"-"(v2, v0)).normalized();
        const d = -n.dot(v0);
        return .{
            .n = n,
            .d = d,
        };
    }

    pub fn intersect(self: Self, ray: Ray) ?f32 {
        const l = vec.Vec4.vec3(self.n, self.d);
        const lv = l.dot(vec.Vec4.vec3(ray.dir, 0));
        if (std.math.fabs(lv) < 1e-5) {
            // parallel
            return null;
        }

        const lq = l.dot(vec.Vec4.vec3(ray.origin, 1));
        const t = -lq / lv;
        return t;
    }
};

/// e-f
/// |/ g
/// o
fn isFGSameSide(e: vec.Vec2, f: vec.Vec2, g: vec.Vec2) bool {
    const n = vec.Vec2.values(-e.y, e.x);
    return n.dot(f) * n.dot(g) >= 0;
}

fn isInside2D(p: vec.Vec2, v0: vec.Vec2, v1: vec.Vec2, v2: vec.Vec2) bool {
    // v0 origin
    if (!isFGSameSide(@"-"(v1, v0), @"-"(v2, v0), @"-"(p, v0))) return false;
    // v1 origin
    if (!isFGSameSide(@"-"(v2, v1), @"-"(v0, v1), @"-"(p, v1))) return false;
    // v2 origin
    if (!isFGSameSide(@"-"(v0, v2), @"-"(v1, v2), @"-"(p, v2))) return false;

    return true;
}

pub fn dropMaxAxis(n: vec.Vec3, points: anytype) [@typeInfo(@TypeOf(points)).Array.len]vec.Vec2 {
    var result: [@typeInfo(@TypeOf(points)).Array.len]vec.Vec2 = undefined;

    const x = std.math.fabs(n.x);
    const y = std.math.fabs(n.y);
    const z = std.math.fabs(n.z);

    if (x > y) {
        if (x > z) {
            // drop x
            for (points) |p, i| {
                result[i] = vec.Vec2.values(p.y, p.z);
            }
        } else {
            // drop z
            for (points) |p, i| {
                result[i] = vec.Vec2.values(p.x, p.y);
            }
        }
    } else {
        if (y > z) {
            // drop y
            for (points) |p, i| {
                result[i] = vec.Vec2.values(p.x, p.z);
            }
        } else {
            // drop z
            for (points) |p, i| {
                result[i] = vec.Vec2.values(p.x, p.y);
            }
        }
    }
    return result;
}

pub const Triangle = struct {
    const Self = @This();

    v0: vec.Vec3,
    v1: vec.Vec3,
    v2: vec.Vec3,

    pub fn getPlain(self: Self) Plain {
        return Plain.triangle(self.v0, self.v1, self.v2);
    }

    pub fn transform(self: Self, m: transform.Mat4) Self {
        return .{
            .v0 = m.applyVec3(self.v0, 1),
            .v1 = m.applyVec3(self.v1, 1),
            .v2 = m.applyVec3(self.v2, 1),
        };
    }

    pub fn intersect(self: Self, ray: Ray) ?f32 {
        const l = self.getPlain();
        const t = l.intersect(ray) orelse {
            return null;
        };

        const p = ray.position(t);

        const p2d = dropMaxAxis(l.n, [_]vec.Vec3{ p, self.v0, self.v1, self.v2 });
        return if (isInside2D(p2d[0], p2d[1], p2d[2], p2d[3])) t else null;
    }
};

test "ray triangle ccw" {
    const ray = Ray{
        .origin = vec.Vec3.values(0, 0, -1),
        .dir = vec.Vec3.values(0, 0, 1),
    };

    const t = Triangle{
        .v0 = vec.Vec3.values(-1, -1, 0),
        .v1 = vec.Vec3.values(1, -1, 0),
        .v2 = vec.Vec3.values(0, 1, 0),
    };
    try std.testing.expectEqual(@as(f32, 1.0), t.intersect(ray).?);
}

test "ray triangle cw" {
    const ray = Ray{
        .origin = vec.Vec3.values(0, 0, -1),
        .dir = vec.Vec3.values(0, 0, 1),
    };

    const t = Triangle{
        .v0 = vec.Vec3.values(1, 2, -3),
        .v2 = vec.Vec3.values(1, -2, -3),
        .v1 = vec.Vec3.values(-1, -2, -3),
    };
    try std.testing.expectEqual(@as(f32, -2.0), t.intersect(ray).?);
}

test "ray not hit" {
    const ray = Ray{
        .origin = vec.Vec3.values(10, 0, -1),
        .dir = vec.Vec3.values(0, 0, 1),
    };
    const p0 = ray.position(3);
    try std.testing.expectEqual(vec.Vec3.values(10, 0, 2), p0);

    const tri = Triangle{
        .v0 = vec.Vec3.values(-1, -1, 0),
        .v1 = vec.Vec3.values(1, -1, 0),
        .v2 = vec.Vec3.values(0, 1, 0),
    };
    const l = tri.getPlain();
    const t = l.intersect(ray).?;
    try std.testing.expectEqual(@as(f32, 1), t);
    const p = ray.position(t);
    try std.testing.expectEqual(vec.Vec3.values(10, 0, 0), p);
    const p2d = dropMaxAxis(l.n, [_]vec.Vec3{ p, tri.v0, tri.v1, tri.v2 });
    try std.testing.expectEqual(vec.Vec2.values(10, 0), p2d[0]);
    try std.testing.expectEqual(vec.Vec2.values(-1, -1), p2d[1]);
    try std.testing.expectEqual(vec.Vec2.values(1, -1), p2d[2]);
    try std.testing.expectEqual(vec.Vec2.values(0, 1), p2d[3]);
    try std.testing.expect(tri.intersect(ray) == null);
}

test "ray negative" {
    const t = Triangle{
        .v0 = vec.Vec3.values(-1, -1, 0),
        .v1 = vec.Vec3.values(1, -1, 0),
        .v2 = vec.Vec3.values(0, 1, 0),
    };
    const l = t.getPlain();
    const ray = Ray{
        .origin = vec.Vec3.values(0, 0, 1),
        .dir = vec.Vec3.values(0, 0, -1),
    };

    try std.testing.expectEqual(@as(f32, 1.0), l.intersect(ray).?);
    try std.testing.expectEqual(@as(f32, 1.0), t.intersect(ray).?);
}

test "ray debug" {
    const ray = Ray{
        .origin = vec.Vec3.values(100, 0, 5),
        .dir = vec.Vec3.values(0, 0, -1),
    };
    const tri = Triangle{
        .v0 = vec.Vec3.values(1, 2, -3),
        .v1 = vec.Vec3.values(1, -2, -3),
        .v2 = vec.Vec3.values(-1, -2, -3),
    };

    const l = tri.getPlain();
    const t = l.intersect(ray).?;
    const p = ray.position(t);
    const p2d = dropMaxAxis(l.n, [_]vec.Vec3{ p, tri.v0, tri.v1, tri.v2 });
    _ = p2d;

    try std.testing.expect(tri.intersect(ray) == null);
    // std.debug.print("{any}\n", .{p2d});
}
