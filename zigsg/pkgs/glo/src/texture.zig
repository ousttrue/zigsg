const gl = @import("gl");

pub const Texture = struct {
    const Self = @This();

    width: c_int,
    height: c_int,
    // gl.GL_RGBA(32bit) or gl.GL_RED(8bit graysclale)
    pixelFormat: c_int,
    handle: gl.GLuint = 0,

    fn _init(self: *Self) void {
        gl.genTextures(1, &self.handle);
    }

    pub fn init(width: c_int, height: c_int, pixelFormat: c_int, data: ?*const u8) Texture {
        var texture = Texture{
            .width = width,
            .height = height,
            .pixelFormat = pixelFormat,
        };
        texture._init();
        // logger.debug(f'Texture: {self.handle}')
        texture.bind();
        defer texture.unbind();
        gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
        // gl.glPixelStorei(gl.UNPACK_ROW_LENGTH, width);
        gl.pixelStorei(gl.UNPACK_SKIP_PIXELS, 0);
        gl.pixelStorei(gl.UNPACK_SKIP_ROWS, 0);
        gl.texImage2D(gl.TEXTURE_2D, 0, texture.pixelFormat, width, height, 0, @intCast(c_uint, texture.pixelFormat), gl.UNSIGNED_BYTE, data);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        return texture;
    }

    pub fn deinit(self: *Self) void {
        gl.deleteTextures(1, &self.handle);
    }

    pub fn bind(self: *Self) void {
        gl.bindTexture(gl.TEXTURE_2D, self.handle);
    }

    pub fn unbind(_: *Self) void {
        gl.bindTexture(gl.TEXTURE_2D, 0);
    }

    pub fn update(self: *Self, x: c_int, y: c_int, w: c_int, h: c_int, data: *const u8) void {
        self.bind();

        gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
        gl.pixelStorei(gl.UNPACK_ROW_LENGTH, self.width);
        gl.pixelStorei(gl.UNPACK_SKIP_PIXELS, x);
        gl.pixelStorei(gl.UNPACK_SKIP_ROWS, y);

        gl.texSubImage2D(gl.TEXTURE_2D, 0, x, y, w, h, @intCast(c_uint, self.pixelFormat), gl.UNSIGNED_BYTE, data);

        gl.pixelStorei(gl.UNPACK_ALIGNMENT, 4);
        gl.pixelStorei(gl.UNPACK_ROW_LENGTH, 0);
        gl.pixelStorei(gl.UNPACK_SKIP_PIXELS, 0);
        gl.pixelStorei(gl.UNPACK_SKIP_ROWS, 0);

        self.unbind();
    }
};
