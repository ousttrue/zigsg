const std = @import("std");
const gl = @import("gl");
const error_handling = @import("./error_handling.zig");

pub fn compile(shader_type: gl.GLuint, src: []const u8) error_handling.ShaderError!gl.GLuint {
    const handle = gl.createShader(shader_type);
    errdefer gl.deleteShader(handle);

    const len = [1]c_int{@intCast(c_int, src.len)};
    const sources: [1]*const u8 = .{&src[0]};
    gl.shaderSource(handle, 1, &sources[0], &len[0]);
    gl.compileShader(handle);

    var status: gl.GLint = undefined;
    gl.getShaderiv(handle, gl.GL_COMPILE_STATUS, &status);
    if (status == gl.GL_TRUE) {
        return handle;
    }

    error_handling.loadCompileErrorMessage(handle);
    return error_handling.ShaderError.CompileError;
}

pub fn link(vs: gl.GLuint, fs: gl.GLuint) error_handling.ShaderError!gl.GLuint {
    const handle = gl.createProgram();
    errdefer gl.deleteProgram(handle);

    gl.attachShader(handle, vs);
    gl.attachShader(handle, fs);
    gl.linkProgram(handle);
    var status: gl.GLint = undefined;
    gl.getProgramiv(handle, gl.GL_LINK_STATUS, &status);
    if (status == gl.GL_TRUE) {
        return handle;
    }

    error_handling.loadLinkErrorMessage(handle);
    return error_handling.ShaderError.LinkError;
}

pub const AttributeLocation = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    name: [:0]const u8,
    location: c_uint,

    pub fn create(allocator: std.mem.Allocator, program: gl.GLuint, name: []const u8) Self {
        var self = Self{
            .allocator = allocator,
            .name = allocator.dupeZ(u8, name) catch unreachable,
            .location = undefined,
        };
        const location = gl.getAttribLocation(program, @ptrCast([*:0]const u8, &self.name[0]));
        std.debug.assert(location != -1);
        self.location = @intCast(c_uint, location);
        return self;
    }
};

pub const VertexLayout = struct {
    attribute: AttributeLocation,
    itemCount: c_int, // maybe float1, 2, 3, 4 and 16
    stride: c_int,
    byteOffset: c_int,
};

fn getLayout(layouts: []const VertexLayout, location: c_uint) ?VertexLayout {
    for (layouts) |*layout| {
        if (layout.attribute.location == location) {
            return layout.*;
        }
    }
    return null;
}

pub const Shader = struct {
    const Self = @This();

    handle: gl.GLuint,
    location_map: std.StringHashMap(c_uint),

    pub fn load(allocator: std.mem.Allocator, vs_src: []const u8, fs_src: []const u8) error_handling.ShaderError!Self {
        var vs = compile(gl.GL_VERTEX_SHADER, vs_src) catch {
            @panic(error_handling.getErrorMessage());
        };
        defer gl.deleteShader(vs);

        var fs = compile(gl.GL_FRAGMENT_SHADER, fs_src) catch {
            @panic(error_handling.getErrorMessage());
        };
        defer gl.deleteShader(fs);

        const handle = link(vs, fs) catch {
            @panic(error_handling.getErrorMessage());
        };
        return Shader{
            .handle = handle,
            .location_map = std.StringHashMap(c_uint).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.location_map.deinit();
        gl.deleteProgram(self.handle);
    }

    pub fn use(self: *const Self) void {
        gl.useProgram(self.handle);
    }

    pub fn unuse(self: *const Self) void {
        _ = self;
        gl.useProgram(0);
    }

    pub fn getLocation(self: *Self, name: []const u8) ?c_uint {
        if (self.location_map.get(name)) |location| {
            return location;
        }

        var buf: [128]u8 = .{};
        std.mem.copy(u8, &buf, name);
        buf[name.len] = 0;

        const location = gl.getUniformLocation(self.handle, @ptrCast([*:0]const u8, &name[0]));
        if (location < 0) {
            return null;
        }
        self.location_map.put(name, @intCast(c_uint, location)) catch @panic("put");
        return @intCast(c_uint, location);
    }

    pub fn _setMat4(_: *Self, location: c_uint, transpose: bool, value: *const f32) void {
        gl.uniformMatrix4fv(location, 1, if (transpose) gl.GL_TRUE else gl.GL_FALSE, value);
    }

    pub fn setMat4(self: *Self, name: []const u8, value: *const f32) void {
        if (self.getLocation(name)) |location| {
            self._setMat4(location, false, value);
        }
    }

    pub fn _setVec4(_: *Self, location: c_uint, value: *const f32) void {
        gl.uniform4fv(location, 1, value);
    }

    pub fn setVec4(self: *Self, name: []const u8, value: *const f32) void {
        if (self.getLocation(name)) |location| {
            self._setVec4(location, value);
        }
    }

    pub fn createVertexLayout(self: *Self, allocator: std.mem.Allocator) []const VertexLayout {
        var count: gl.GLint = undefined;
        gl.getProgramiv(self.handle, gl.GL_ACTIVE_ATTRIBUTES, &count);
        var tmp = allocator.alloc(VertexLayout, @intCast(usize, count)) catch @panic("alloc []VertexLayout");
        defer allocator.free(tmp);

        var stride: c_int = 0;
        var i: c_uint = 0;
        while (i < count) : (i += 1) {
            var buffer: [1024]u8 = undefined;
            var length: c_int = undefined;
            var size: gl.GLsizei = undefined;
            var gl_type: gl.GLenum = undefined;
            gl.getActiveAttrib(self.handle, i, @intCast(gl.GLuint, buffer.len), &length, &size, &gl_type, &buffer[0]);
            // https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/glGetActiveAttrib.xhtml
            std.debug.assert(size == 1);
            const name = buffer[0..@intCast(usize, length)];
            const attribute = AttributeLocation.create(allocator, self.handle, name);
            const itemCount: c_int = switch (gl_type) {
                gl.GL_FLOAT_VEC2 => 2, // 0x8B50
                gl.GL_FLOAT_VEC3 => 3, // 0x8B51
                gl.GL_FLOAT_VEC4 => 4, // 0x8B52
                else => {
                    std.log.err("gl_type: 0x{x}", .{gl_type});
                    @panic("not implemented");
                },
            };
            var offset = itemCount * 4;
            tmp[i] = VertexLayout{
                .attribute = attribute,
                .itemCount = itemCount,
                .stride = 0,
                .byteOffset = offset,
            };
            stride += offset;
        }

        var layouts = allocator.dupe(VertexLayout, tmp) catch @panic("dupe");
        var offset: c_int = 0;
        i = 0;
        while (i < count) : (i += 1) {
            if (getLayout(tmp, i)) |layout| {
                layouts[i] = VertexLayout{ .attribute = layout.attribute, .itemCount = layout.itemCount, .stride = stride, .byteOffset = offset };
                offset += layout.byteOffset;
            } else {
                @panic("not found");
            }
        }
        return layouts;
    }
};

pub const UniformLocation = struct {
    const Self = @This();
    name: []const u8,
    location: c_int,

    pub fn init(program: c_uint, name: []const u8) Self {
        const location = gl.getUniformLocation(program, &name[0]);
        if (location == -1) {
            std.log.debug("{s}: -1", .{name});
        }
        return .{
            .name = name,
            .location = location,
        };
    }

    pub fn setInt(self: *Self, value: c_int) void {
        gl.uniform1i(self.location, value);
    }

    pub fn setFloat2(self: *Self, value: *const f32) void {
        gl.uniform2fv(self.location, 1, value);
    }

    pub fn setMat4(self: *const Self, value: *const f32, __: struct { transpose: bool = false, count: c_uint = 1 }) void {
        gl.uniformMatrix4fv(self.location, @intCast(c_int, __.count), if (__.transpose) gl.TRUE else gl.FALSE, value);
    }
};

pub const UniformBlockIndex = struct {
    const Self = @This();

    name: []const u8,
    index: c_uint,

    pub fn init(program: c_uint, name: []const u8) Self {
        const index = gl.getUniformBlockIndex(program, &name[0]);
        return .{ .name = name, .index = index };
    }
};
