const std = @import("std");
const Vector = std.meta.Vector;

pub fn vdot4(lhs: Vector(4, f32), rhs: Vector(4, f32)) f32 {
    return @reduce(.Add, lhs * rhs);
}
pub fn vdot3(lhs: Vector(3, f32), rhs: Vector(3, f32)) f32 {
    return @reduce(.Add, lhs * rhs);
}

test "vdot" {
    const v1234: [4]f32 = .{ 1, 2, 3, 4 };
    try std.testing.expectEqual(@as(f32, 30.0), vdot4(v1234, v1234));
    const v123 = [_]f32{ 1, 2, 3 };
    try std.testing.expectEqual(@as(f32, 14.0), vdot3(v123, v123));
}
