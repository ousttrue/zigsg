const gl = @import("gl");
const shader_program = @import("./shader_program.zig");

pub const Vbo = struct {
    const Self = @This();

    handle: gl.GLuint,

    pub fn init() Self {
        var handle: gl.GLuint = undefined;
        gl.genBuffers(1, &handle);

        return .{
            .handle = handle,
        };
    }

    pub fn deinit(self: *Self) void {
        gl.deleteBuffers(1, &self.handle);
    }

    pub fn bind(self: *const Self) void {
        gl.bindBuffer(gl.GL_ARRAY_BUFFER, self.handle);
    }

    pub fn unbind(self: Self) void {
        _ = self;
        gl.bindBuffer(gl.GL_ARRAY_BUFFER, 0);
    }

    pub fn setVertices(self: *Self, comptime T: type, vertices: []const T, isDynamic: bool) void {
        self.bind();
        gl.bufferData(gl.GL_ARRAY_BUFFER, @intCast(gl.GLsizeiptr, @sizeOf(T) * vertices.len), &vertices[0], if (isDynamic) gl.GL_DYNAMIC_DRAW else gl.GL_STATIC_DRAW);
        self.unbind();
    }

    pub fn update(self: *Self, vertices: anytype, __: struct { offset: u32 = 0 }) void {
        const T = @TypeOf(vertices);
        switch (@typeInfo(T)) {
            .Array => {},
            else => @compileError("not array"),
        }
        self.bind();
        gl.bufferSubData(gl.ARRAY_BUFFER, __.offset, @sizeOf(T), &vertices);
        self.unbind();
    }
};

pub const Ibo = struct {
    const Self = @This();

    handle: gl.GLuint = undefined,
    format: gl.GLuint = 0,

    pub fn init() Self {
        var self = Self{};
        gl.genBuffers(1, &self.handle);
        return self;
    }

    pub fn deinit(self: *Self) void {
        gl.deleteBuffers(1, &self.handle);
    }

    pub fn bind(self: Self) void {
        gl.bindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.handle);
    }

    pub fn unbind(_: Self) void {
        gl.bindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
    }

    pub fn setIndices(self: *Self, comptime T: type, indices: []const T, isDynamic: bool) void {
        switch (@sizeOf(T)) {
            2 => self.format = gl.GL_UNSIGNED_SHORT,
            4 => self.format = gl.GL_UNSIGNED_INT,
            else => @panic("not implemented"),
        }
        self.bind();
        gl.bufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @intCast(gl.GLsizeiptr, @sizeOf(T) * indices.len), &indices[0], if (isDynamic) gl.GL_DYNAMIC_DRAW else gl.GL_STATIC_DRAW);
        self.unbind();
    }

    pub fn update(self: Self, indices: anytype, __: struct { offset: u32 = 0 }) void {
        const T = @TypeOf(indices);
        switch (@typeInfo(T)) {
            .Array => {},
            else => @compileError("not array"),
        }
        self.bind();
        gl.bufferSubData(gl.GL_ELEMENT_ARRAY_BUFFER, __.offset, @sizeOf(T), &indices);
        self.unbind();
    }
};

pub const Vao = struct {
    const Self = @This();

    handle: gl.GLuint,
    vbo: Vbo,
    ibo: ?Ibo,

    pub fn init(vbo: Vbo, layouts: []const shader_program.VertexLayout, ibo: ?Ibo) Self {
        var handle: gl.GLuint = undefined;
        gl.genVertexArrays(1, &handle);

        var self = Self{
            .handle = handle,
            .vbo = vbo,
            .ibo = ibo,
        };

        vbo.bind();
        defer vbo.unbind();

        self.bind();
        for (layouts) |*layout| {
            gl.enableVertexAttribArray(layout.attribute.location);
            const value = @intCast(c_longlong, layout.byteOffset);
            // const p = if (value == 0) null else @intToPtr(*anyopaque, value);
            gl.vertexAttribPointer(layout.attribute.location, layout.itemCount, gl.GL_FLOAT, gl.GL_FALSE, layout.stride, value);
        }
        if (ibo) |ibo_| {
            self.ibo = ibo_;
            ibo_.bind();
        }

        self.unbind();
        if (ibo) |ibo_| {
            self.ibo = ibo_;
            ibo_.unbind();
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        gl.deleteVertexArrays(1, &self.handle);
    }

    pub fn bind(self: *const Self) void {
        gl.bindVertexArray(self.handle);
    }

    pub fn unbind(self: *const Self) void {
        _ = self;
        gl.bindVertexArray(0);
    }

    pub fn draw(self: *const Self, count: u32, __default__: struct { offset: u32 = 0, topology: gl.GLenum = gl.GL_TRIANGLES }) void {
        self.bind();
        defer self.unbind();

        if (self.ibo) |ibo_| {
            gl.drawElements(__default__.topology, @intCast(i32, count), ibo_.format, __default__.offset);
        } else {
            gl.drawArrays(__default__.topology, @intCast(i32, __default__.offset), @intCast(i32, count));
        }
    }
};
