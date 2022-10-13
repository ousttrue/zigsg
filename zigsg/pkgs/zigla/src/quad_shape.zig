const std = @import("std");
const vec = @import("./vec.zig");
const rotation = @import("./rotation.zig");
const transformation = @import("./transformation.zig");
const ray_intersection = @import("./ray_intersection.zig");
const camera_types = @import("./camera_types.zig");
const util = @import("./util.zig");
const Ray = ray_intersection.Ray;
const Triangle = ray_intersection.Triangle;
const @"+" = util.@"+";
const @"*" = util.@"*";
const @"-" = util.@"-";

pub const Quad = struct {
    const Self = @This();

    t0: Triangle,
    t1: Triangle,

    pub fn from_points(v0: vec.Vec3, v1: vec.Vec3, v2: vec.Vec3, v3: vec.Vec3) Self {
        return Self{
            .t0 = Triangle{ .v0 = v0, .v1 = v1, .v2 = v2 },
            .t1 = Triangle{ .v0 = v2, .v1 = v3, .v2 = v0 },
        };
    }

    pub fn transform(self: Self, m: transformation.Mat4) Self {
        return Self{
            .t0 = self.t0.transform(m),
            .t1 = self.t1.transform(m),
        };
    }

    pub fn intersect(self: Self, ray: Ray) ?f32 {
        if (self.t0.intersect(ray)) |h0| {
            if (self.t1.intersect(ray)) |h1| {
                return if (h0 < h1) h0 else h1;
            } else {
                return h0;
            }
        } else {
            return self.t1.intersect(ray);
        }
    }
};

pub const ShapeState = enum(u32) {
    NONE = 0x00,
    HOVER = 0x01,
    SELECT = 0x02,
    DRAG = 0x04,
    HIDE = 0x08,
    _,
};

pub const StateReference = struct {
    const Self = @This();

    state: [*]f32,
    stride: u32,
    count: u32,

    pub fn setState(self: *Self, fstate: ShapeState) void {
        const new_state = @intToFloat(f32, @enumToInt(fstate));
        var i: i32 = 0;
        var p = self.state;
        while (i < self.count) : ({
            i += 1;
            p += self.stride;
        }) {
            p.* = new_state;
        }
    }

    pub fn addState(self: *Self, state: ShapeState) void {
        const value = @floatToInt(u32, self.state[0]) | @enumToInt(state);
        const new_state = @intToEnum(ShapeState, value);
        self.setState(new_state);
    }

    pub fn removeState(self: *Self, state: ShapeState) void {
        const new_state = @intToEnum(ShapeState, @floatToInt(u32, self.state[0]) & ~@enumToInt(state));
        self.setState(new_state);
    }

    pub fn hasState(self: Self, state: ShapeState) bool {
        return (@floatToInt(u32, self.state[0]) & @enumToInt(state)) != 0;
    }
};

pub const Shape = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    quads: []const Quad,
    matrix: *transformation.Mat4,
    state: StateReference,
    drag_factory: ?*const DragFactory = null,

    pub fn init(allocator: std.mem.Allocator, quads: []const Quad, pMatrix: *transformation.Mat4, state: StateReference) Self {
        var self = Self{
            .allocator = allocator,
            .quads = allocator.dupe(Quad, quads) catch @panic("dupe"),
            .matrix = pMatrix,
            .state = state,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.quads);
    }

    pub fn setPosition(self: *Self, p: vec.Vec3) void {
        self.matrix._3 = vec.Vec4.vec3(p, 1);
    }

    pub fn localRay(self: Self, ray: Ray) Ray {
        var rb = transformation.Transform{ .mat4 = self.matrix.* };
        rb = rb.inversed();
        return Ray{
            .origin = rb.applyVec3(ray.origin, 1),
            .dir = rb.applyVec3(ray.dir, 0),
        };
    }

    pub fn intersect(self: *const Self, ray: Ray) ?f32 {
        if (self.state.hasState(ShapeState.HIDE)) {
            return null;
        }

        var closest: ?f32 = null;

        const local_ray = self.localRay(ray);
        for (self.quads) |quad| {
            if (quad.intersect(local_ray)) |hit| {
                closest = if (closest) |closest_hit|
                    if (hit < closest_hit) hit else closest_hit
                else
                    hit;
            }
        }
        // for (self.quads) |quad_origin| {
        //     const quad = quad_origin.transform(self.matrix.*);
        //     if (quad.intersect(ray)) |hit| {
        //         closest = if (closest) |closest_hit|
        //             if (hit < closest_hit) hit else closest_hit
        //         else
        //             hit;
        //     }
        // }

        return closest;
    }
};

pub const ScreenLine = struct {
    const Self = @This();

    start: vec.Vec2,
    dir: vec.Vec2,

    pub fn init(start: vec.Vec2, dir: vec.Vec2) Self {
        return .{
            .start = start,
            .dir = dir.normalized(),
        };
    }

    pub fn beginEnd(start: vec.Vec2, end: vec.Vec2, w: f32, h: f32) Self {
        return Self.init(start, @"-"(end, start), w, h);
    }

    pub fn drag(self: *Self, v: vec.Vec2) f32 {
        return @"-"(v, self.start).dot(self.dir);
    }
};

pub const DragContext = struct {
    const Self = @This();

    line: ScreenLine,
    init_matrix: transformation.Mat4,
    axis: vec.Vec3,

    pub fn init(line: ScreenLine, init_matrix: transformation.Mat4, axis: vec.Vec3) Self {
        return .{
            .line = line,
            .init_matrix = init_matrix,
            .axis = axis,
        };
    }

    pub fn drag(self: *Self, cursor_pos: vec.Vec2) transformation.Mat4 {
        const d = self.line.drag(cursor_pos);
        const angle = d * 0.02;
        const delta = rotation.Mat3.angleAxis(angle, self.axis);
        return @"*"(transformation.Mat4.mat3(delta), self.init_matrix);
    }
};

pub const DragFactory = fn (cursor_pos: vec.Vec2, init_matrix: transformation.Mat4, camera: *camera_types.Camera) DragContext;

const identity = rotation.Mat3{};

/// 円盤面のドラッグ
pub fn RingDragFactory(comptime axis_index: usize) type {
    return struct {
        pub fn createRingDragContext(start_screen_pos: vec.Vec2, init_matrix: transformation.Mat4, camera: *camera_types.Camera) DragContext {
            const vp = camera.getViewProjectionMatrix();
            const center_pos = @"*"(init_matrix, vp).apply(vec.Vec4.values(0, 0, 0, 1));
            const cx = center_pos.x / center_pos.w;
            const cy = center_pos.y / center_pos.w;
            const center_screen_pos = vec.Vec2.values(
                (cx * 0.5 + 0.5) * @intToFloat(f32, camera.projection.width),
                (cy * 0.5 + 0.5) * @intToFloat(f32, camera.projection.height),
            );
            const screen_dir = @"-"(start_screen_pos, center_screen_pos);
            var n = vec.Vec2.values(-screen_dir.y, screen_dir.x);
            n.normalize();

            const view_axis = @"*"(init_matrix, camera.view.getViewMatrix()).getRow(axis_index).toVec3();
            if (view_axis.dot(vec.Vec3.values(0, 0, 1)) < 0) {
                n = n.inversed();
            }

            return DragContext.init(ScreenLine.init(start_screen_pos, n), init_matrix, identity.getRow(axis_index));
        }
    };
}

/// 車輪面のドラッグ
pub fn RollDragFactory(comptime axis_index: usize) type {
    return struct {
        pub fn createRingDragContext(start_screen_pos: vec.Vec2, init_matrix: transformation.Mat4, camera: *camera_types.Camera) DragContext {
            var view_axis = @"*"(init_matrix, camera.view.getViewMatrix()).getRow(axis_index).toVec3();
            const n = vec.Vec2.values(view_axis.y, -view_axis.x).normalized();
            return DragContext.init(ScreenLine.init(start_screen_pos, n), init_matrix, identity.getRow(axis_index));
        }
    };
}

/// height
/// A
///     4 7
/// 0 3+-+    depth
/// +-+| |   /
/// | |+-+  /
/// +-+5 6 /
/// 1 2   /
/// --------> width
pub fn createCube(width: f32, height: f32, depth: f32) [6]Quad {
    const x = width / 2;
    const y = height / 2;
    const z = depth / 2;
    const v0 = vec.Vec3.values(-x, y, z);
    const v1 = vec.Vec3.values(-x, -y, z);
    const v2 = vec.Vec3.values(x, -y, z);
    const v3 = vec.Vec3.values(x, y, z);
    const v4 = vec.Vec3.values(-x, y, -z);
    const v5 = vec.Vec3.values(-x, -y, -z);
    const v6 = vec.Vec3.values(x, -y, -z);
    const v7 = vec.Vec3.values(x, y, -z);
    return .{
        Quad.from_points(v0, v1, v2, v3),
        Quad.from_points(v3, v2, v6, v7),
        Quad.from_points(v7, v6, v5, v4),
        Quad.from_points(v4, v5, v1, v0),
        Quad.from_points(v4, v0, v3, v7),
        Quad.from_points(v1, v5, v6, v2),
    };
}

pub fn createRing(comptime sections: usize, axis: vec.Vec3, start: vec.Vec3, inner: f32, outer: f32, depth: f32) [sections * 2]Quad {
    const delta = std.math.pi * 2.0 / @as(f32, sections);
    var vertices: [sections]vec.Vec3 = undefined;
    for (vertices) |*v, i| {
        v.* = rotation.Quaternion.angleAxis(@intToFloat(f32, i) * delta, axis).rotate(start);
    }

    var quads: [sections * 2]Quad = undefined;
    const d = axis.mul(depth * 0.5);
    for (vertices) |v, i| {
        const vv = vertices[(i + 1) % sections];
        const v0 = @"+"(d, v.mul(inner));
        const v1 = @"+"(d, v.mul(outer));
        const v2 = @"+"(d, vv.mul(outer));
        const v3 = @"+"(d, vv.mul(inner));
        const v4 = @"+"(d.inversed(), v.mul(inner));
        const v5 = @"+"(d.inversed(), v.mul(outer));
        const v6 = @"+"(d.inversed(), vv.mul(outer));
        const v7 = @"+"(d.inversed(), vv.mul(inner));
        //         v7 v6
        // v3 v2 v4 v5
        // v0 v1
        quads[i * 2] = Quad.from_points(v0, v1, v2, v3);
        quads[i * 2 + 1] = Quad.from_points(v7, v6, v5, v4);
    }

    return quads;
}

pub fn createXRing(comptime sections: usize, inner: f32, outer: f32, depth: f32) [sections * 2]Quad {
    return createRing(sections, vec.Vec3.values(1, 0, 0), vec.Vec3.values(0, 1, 0), inner, outer, depth);
}

pub fn createYRing(comptime sections: usize, inner: f32, outer: f32, depth: f32) [sections * 2]Quad {
    return createRing(sections, vec.Vec3.values(0, 1, 0), vec.Vec3.values(0, 0, 1), inner, outer, depth);
}

pub fn createZRing(comptime sections: usize, inner: f32, outer: f32, depth: f32) [sections * 2]Quad {
    return createRing(sections, vec.Vec3.values(0, 0, 1), vec.Vec3.values(1, 0, 0), inner, outer, depth);
}

pub fn createRoll(comptime sections: usize, axis: vec.Vec3, start: vec.Vec3, outer: f32, depth: f32) [sections]Quad {
    const delta = std.math.pi * 2.0 / @as(f32, sections);
    var vertices: [sections]vec.Vec3 = undefined;
    for (vertices) |*v, i| {
        v.* = rotation.Quaternion.angleAxis(@intToFloat(f32, i) * delta, axis).rotate(start);
    }

    var quads: [sections]Quad = undefined;
    const d = axis.mul(depth * 0.5);
    for (vertices) |v, i| {
        const vv = vertices[(i + 1) % sections];
        // const v0 = @"+"(d, v.mul(inner));
        const v1 = @"+"(d, v.mul(outer));
        const v2 = @"+"(d, vv.mul(outer));
        // const v3 = @"+"(d, vv.mul(inner));
        // const v4 = @"+"(d.inversed(), v.mul(inner));
        const v5 = @"+"(d.inversed(), v.mul(outer));
        const v6 = @"+"(d.inversed(), vv.mul(outer));
        // const v7 = @"+"(d.inversed(), vv.mul(inner));
        //         v7 v6
        // v3 v2 v4 v5
        // v0 v1
        quads[i] = Quad.from_points(v1, v5, v6, v2);
    }
    return quads;
}

pub fn createXRoll(comptime sections: usize, outer: f32, depth: f32) [sections]Quad {
    return createRoll(sections, vec.Vec3.values(1, 0, 0), vec.Vec3.values(0, 1, 0), outer, depth);
}
pub fn createYRoll(comptime sections: usize, outer: f32, depth: f32) [sections]Quad {
    return createRoll(sections, vec.Vec3.values(0, 1, 0), vec.Vec3.values(0, 0, 1), outer, depth);
}
pub fn createZRoll(comptime sections: usize, outer: f32, depth: f32) [sections]Quad {
    return createRoll(sections, vec.Vec3.values(0, 0, 1), vec.Vec3.values(1, 0, 0), outer, depth);
}

test "Shape" {
    const quads = createCube(2, 4, 6);
    var m = transformation.Mat4{};
    var s: [1]f32 = .{0};
    var state = StateReference{
        .state = &s,
        .count = 1,
        .stride = 0,
    };
    const allocator = std.testing.allocator;
    var cube = Shape.init(allocator, &quads, &m, state);
    defer cube.deinit();

    const ray = Ray{
        .origin = vec.Vec3.values(0, 0, 5),
        .dir = vec.Vec3.values(0, 0, -1),
    };

    const localRay = cube.localRay(ray);
    try std.testing.expectEqual(vec.Vec3.values(0, 0, 5), localRay.origin);
    try std.testing.expectEqual(vec.Vec3.values(0, 0, -1), localRay.dir);

    const t = cube.intersect(ray);
    try std.testing.expectEqual(@as(f32, 2.0), t.?);
}
