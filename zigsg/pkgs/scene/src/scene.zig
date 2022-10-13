const std = @import("std");
const zigla = @import("zigla");
const Model = @import("./model.zig").Model;

pub const Scene = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    light: zigla.Vec4 = zigla.Vec4.values(1, 2, 3, 0).normalized(),
    model: ?Model = null,

    pub fn new(allocator: std.mem.Allocator) *Self {
        var scene = allocator.create(Scene) catch @panic("create");
        scene.* = Scene{
            .allocator = allocator,
        };
        // scene.loader = scene_loader.Loader.create(scene_loader.Triangle.new(allocator));
        return scene;
    }

    pub fn delete(self: *Self) void {
        if (self.model) |model| {
            model.deinit();
        }
        self.allocator.destroy(self);
    }

    pub fn render(self: *Self, camera: *zigla.Camera) void {
        if (self.model) |*model| {
            model.render(camera, self.light);
        }
    }
};
