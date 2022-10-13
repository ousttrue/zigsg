//! zig linear algebra
//!
//! R | 0
//! --+--
//! T | 1
//!

pub const vec = @import("./vec.zig");
pub const rotation = @import("./rotation.zig");
pub const tramsformation = @import("./transformation.zig");
pub const ray_intersection = @import("./ray_intersection.zig");
pub const quad_shape = @import("./quad_shape.zig");
pub const camera_types = @import("./camera_types.zig");
pub const colors = @import("./colors.zig");
pub const util = @import("./util.zig");

pub const @"*" = util.@"*";
pub const @"+" = util.@"+";
pub const @"-" = util.@"-";

// vec
pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;

// rotation
pub const AngleAxis = rotation.AngleAxis;
pub const Mat3 = rotation.Mat3;
pub const Quaternion = rotation.Quaternion;
pub const Rotation = rotation.Rotation;

// transformation
pub const Mat4 = tramsformation.Mat4;
pub const Transform = tramsformation.Transform;

pub const Camera = camera_types.Camera;
pub const Ray = ray_intersection.Ray;
pub const Shape = quad_shape.Shape;
pub const DragContext = quad_shape.DragContext;
