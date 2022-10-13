const std = @import("std");
const zigla = @import("zigla");
const TypeEraser = @import("./type_eraser.zig").TypeEraser;

pub fn readsource(allocator: std.mem.Allocator, arg: []const u8) ![:0]const u8 {
    var file = try std.fs.cwd().openFile(arg, .{});
    defer file.close();
    const file_size = try file.getEndPos();

    var buffer = try allocator.allocSentinel(u8, file_size, 0);
    errdefer allocator.free(buffer);

    const bytes_read = try file.read(buffer);
    std.debug.assert(bytes_read == file_size);
    return buffer;
}

pub const Vertex = struct {
    position: zigla.Vec3,
    normal: zigla.Vec3,
    color: zigla.Vec3,

    pub fn create(v: anytype) Vertex {
        return .{
            .position = .{ .x = v.@"0".@"0", .y = v.@"0".@"1", .z = v.@"0".@"2" },
            .normal = .{ .x = v.@"1".@"0", .y = v.@"1".@"1", .z = v.@"1".@"2" },
            .color = .{ .x = v.@"2".@"0", .y = v.@"2".@"1", .z = v.@"2".@"2" },
        };
    }
};

const g_vertices: [3]Vertex = .{
    Vertex.create(.{ .{ -2, -2, 0 }, .{ 0, 0, 1 }, .{ 1.0, 0.0, 0.0 } }),
    Vertex.create(.{ .{ 2, -2, 0 }, .{ 0, 0, 1 }, .{ 0.0, 1.0, 0.0 } }),
    Vertex.create(.{ .{ 0.0, 2, 0 }, .{ 0, 0, 1 }, .{ 0.0, 0.0, 1.0 } }),
};

pub const Triangle = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator) *Self {
        var self = allocator.create(Self) catch unreachable;
        self.* = Self{ .allocator = allocator };
        return self;
    }

    pub fn delete(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn getVertices(_: *Self) []const Vertex {
        return &g_vertices;
    }

    pub fn getIndices(_: *Self) ?[]const u32 {
        return null;
    }
};

pub const Finalizer = fn (self: *anyopaque) void;
pub const GetVertices = fn (self: *anyopaque) []const Vertex;
pub const GetIndices = fn (self: *anyopaque) ?[]const u32;

pub const Loader = struct {
    const Self = @This();

    ptr: *anyopaque,
    _deinit: *const Finalizer,
    // interfaces
    _getVertices: *const GetVertices,
    _getIndices: *const GetIndices,

    pub fn create(ptr: anytype) Self {
        const T = @TypeOf(ptr);
        const info = @typeInfo(T);
        const E = info.Pointer.child;
        return Self{
            .ptr = ptr,
            ._deinit = &TypeEraser(E, "delete").call,
            ._getVertices = &TypeEraser(E, "getVertices").call,
            ._getIndices = &TypeEraser(E, "getIndices").call,
        };
    }

    pub fn deinit(self: *Self) void {
        self._deinit.*(self.ptr);
    }

    pub fn getVertices(self: *Self) []const Vertex {
        return self._getVertices.*(self.ptr);
    }

    pub fn getIndices(self: *Self) ?[]const u32 {
        return self._getIndices.*(self.ptr);
    }
};

pub const Builder = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),

    pub fn new(allocator: std.mem.Allocator) *Self {
        var self = allocator.create(Self) catch unreachable;
        self.* = Self{
            .allocator = allocator,
            .vertices = std.ArrayList(Vertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
        };
        return self;
    }

    pub fn delete(self: *Self) void {
        self.vertices.deinit();
        self.indices.deinit();
        self.allocator.destroy(self);
    }

    pub fn getVertices(self: *Self) []const Vertex {
        return self.vertices.items;
    }

    pub fn getIndices(self: *Self) ?[]const u32 {
        return self.indices.items;
    }
};
