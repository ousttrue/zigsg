const std = @import("std");

pub fn nearlyEqual(comptime epsilon: anytype, comptime n: usize, lhs: [n]@TypeOf(epsilon), rhs: [n]@TypeOf(epsilon)) bool {
    for (lhs) |l, i| {
        const delta = std.math.fabs(l - rhs[i]);
        if (delta > epsilon) {
            std.debug.print("\n", .{});
            std.debug.print("lhs: {any}\n", .{lhs});
            std.debug.print("rhs: {any}\n", .{rhs});
            std.debug.print("{}: {}, {} => {}\n", .{ i, l, rhs[i], delta });
            return false;
        }
    }
    return true;
}

pub fn sign(x: f32) f32 {
    return if (x >= 0.0) 1.0 else -1.0;
}

pub fn norm(a: f32, b: f32, c: f32, d: f32) f32 {
    return std.math.sqrt(a * a + b * b + c * c + d * d);
}

pub fn @"+"(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    return lhs.add(rhs);
}
pub fn @"-"(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    return lhs.sub(rhs);
}
pub fn @"*"(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    return lhs.mul(rhs);
}

fn Child(comptime t: type) type {
    return switch (@typeInfo(t)) {
        .Array => |a| a.child,
        .Pointer => |p| p.child,
        else => @compileError("not implemented"),
    };
}
