const std = @import("std");

pub const GlbError = error{
    InvalidMagic,
    UnknownVersion,
    Format,
};

const MAGIC: u32 = 0x46546C67;
const JSON_CHUNK: u32 = 0x4E4F534A;
const BIN_CHUNK: u32 = 0x004E4942;

const Reader = struct {
    const Self = @This();

    buffer: []const u8,
    pos: u32 = 0,

    pub fn init(buffer: []const u8) Reader {
        return .{
            .buffer = buffer,
        };
    }

    pub fn isEnd(self: *Self) bool {
        return self.pos >= self.buffer.len;
    }

    pub fn read(self: *Self, size: u32) []const u8 {
        const slice = self.buffer[self.pos .. self.pos + size];
        self.pos += size;
        return slice;
    }

    pub fn readInt(self: *Self, comptime t: type) !t {
        var slice = self.read(4);
        var s = std.io.fixedBufferStream(slice);
        var r = s.reader();
        return r.readInt(t, .Little);
    }
};

pub const Glb = struct {
    jsonChunk: []const u8 = undefined,
    binChunk: []const u8 = undefined,

    pub fn parse(data: []const u8) !Glb {
        var r = Reader.init(data);
        const magic = try r.readInt(u32);
        if (magic != MAGIC) {
            return GlbError.InvalidMagic;
        }

        const version = try r.readInt(u32);
        if (version != 2) {
            return GlbError.UnknownVersion;
        }

        _ = try r.readInt(u32);
        var glb = Glb{};
        while (!r.isEnd()) {
            const chunkLength = try r.readInt(u32);
            const chunkType = try r.readInt(u32);
            switch (chunkType) {
                JSON_CHUNK => glb.jsonChunk = r.read(chunkLength),
                BIN_CHUNK => glb.binChunk = r.read(chunkLength),
                else => @panic("unknown chunk"),
            }
        }
        return glb;
    }
};

pub const Asset = struct {
    generator: ?[]const u8,
    version: ?[]const u8,
};

pub const Scene = struct {
    nodes: []const u32 = &.{},
};

pub const Node = struct {
    name: ?[]const u8 = null,
    children: []const u32 = &.{},
    matrix: ?[16]f32 = null,
    translation: [3]f32 = .{ 0, 0, 0 },
    rotation: [4]f32 = .{ 0, 0, 0, 1 },
    scale: [3]f32 = .{ 1, 1, 1 },
    camera: ?u32 = null,
    mesh: ?u32 = null,
};

pub const Camera = struct {
    perspective: ?struct {
        aspectRatio: ?f32,
        yfov: ?f32,
        zfar: ?f32,
        znear: ?f32,
    },
    @"type": ?[]const u8,
};

pub const Primitive = struct {
    attributes: struct { NORMAL: ?u32 = null, POSITION: u32, TEXCOORD_0: ?u32 = null },
    indices: ?u32 = null,
    mode: ?u32 = null,
    material: ?u32 = null,
};

pub const Mesh = struct {
    name: ?[]const u8 = null,
    primitives: []Primitive = &.{},
};

pub const Accessor = struct {
    const Self = @This();

    bufferView: usize,
    byteOffset: usize = 0,
    componentType: u32,
    count: usize,
    max: ?[]f32 = null,
    min: ?[]f32 = null,
    @"type": []const u8,

    pub fn itemSize(self: Self) usize {
        const t = self.@"type";
        const component_count: usize =
            if (std.mem.eql(u8, t, "SCALAR")) @as(usize, 1) //
        else if (std.mem.eql(u8, t, "VEC2")) @as(usize, 2) //
        else if (std.mem.eql(u8, t, "VEC3")) @as(usize, 3) //
        else if (std.mem.eql(u8, t, "VEC4")) @as(usize, 4) //
        else if (std.mem.eql(u8, t, "MAT2")) @as(usize, 4) //
        else if (std.mem.eql(u8, t, "MAT3")) @as(usize, 9) //
        else if (std.mem.eql(u8, t, "MAT4")) @as(usize, 16) //
        else unreachable;

        const component_byte_size: usize = switch (self.componentType) {
            5120 => 1,
            5121 => 1,
            5122 => 2,
            5123 => 2,
            5125 => 4,
            5126 => 4,
            else => unreachable,
        };

        return component_count * component_byte_size;
    }
};

pub const Material = struct {
    pbrMetallicRoughness: ?struct {
        baseColorTexture: ?struct { index: ?u32 },
        metallicFactor: ?f32,
    },
    emissiveFactor: ?[3]f32,
    name: ?[]const u8,
};

pub const Texture = struct {
    sampler: ?u32,
    source: ?u32,
};

pub const Image = struct {
    uri: ?[]const u8,
};

pub const Sampler = struct {
    magFilter: ?u32,
    minFilter: ?u32,
    wrapS: ?u32,
    wrapT: ?u32,
};

pub const BufferView = struct {
    buffer: usize = 0,
    byteOffset: usize = 0,
    byteLength: usize,
    byteStride: ?usize = null,
    target: ?u32 = null,
};

pub const Buffer = struct {
    byteLength: ?u32 = null,
    uri: ?[]const u8 = null,
};

pub const Gltf = struct {
    // asset: ?Asset,
    // scene: ?u32,
    scenes: []Scene = &.{},
    nodes: []Node = &.{},
    // cameras: ?[]Camera,
    meshes: []Mesh = &.{},
    accessors: []Accessor = &.{},
    // materials: ?[]Material,
    // textures: ?[]Texture,
    // images: ?[]Image,
    // samplers: ?[]Sampler,
    bufferViews: []BufferView = &.{},
    // buffers: ?[]Buffer,
};

pub const GtlfBufferReader = struct {
    const Self = @This();

    buffers: []const []const u8,
    bufferViews: []const BufferView,
    accessors: []const Accessor,

    pub fn getBytesFromAccessor(self: Self, accessor_index: usize) []const u8 {
        const accessor = self.accessors[accessor_index];
        const buffer_view = self.bufferViews[accessor.bufferView];
        const buffer_view_bytes = self.buffers[0][buffer_view.byteOffset .. buffer_view.byteOffset + buffer_view.byteLength];
        return buffer_view_bytes[accessor.byteOffset .. accessor.byteOffset + accessor.count * accessor.itemSize()];
    }

    pub fn getTypedFromAccessor(self: Self, comptime T: type, accessor_index: usize) []const T {
        const bytes = self.getBytesFromAccessor(accessor_index);
        const count = self.accessors[accessor_index].count;
        return @ptrCast([*]const T, @alignCast(@alignOf(T), &bytes[0]))[0..count];
    }

    pub fn getUIntIndicesFromAccessor(self: Self, accessor_index: usize, out: []u32, vertex_offset: usize) void {
        const indices_bytes = self.getBytesFromAccessor(accessor_index);
        const accessor = self.accessors[accessor_index];
        const index_count = accessor.count;
        switch (accessor.componentType) {
            5120, 5121 => {
                for (indices_bytes[0..index_count]) |index, j| {
                    out[j] = index + @intCast(u8, vertex_offset);
                }
            },
            5122, 5123 => {
                const indices = @ptrCast([*]const u16, @alignCast(@alignOf(u16), &indices_bytes[0]))[0..index_count];
                for (indices) |index, j| {
                    out[j] = index + @intCast(u16, vertex_offset);
                }
            },
            5125 => {
                const indices = @ptrCast([*]const u32, @alignCast(@alignOf(u32), &indices_bytes[0]))[0..index_count];
                for (indices) |index, j| {
                    out[j] = index + @intCast(u32, vertex_offset);
                }
            },
            else => unreachable,
        }
    }
};
