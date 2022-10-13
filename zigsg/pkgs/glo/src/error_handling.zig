const gl = @import("gl");

pub const ShaderError = error{
    CompileError,
    LinkError,
};

var error_buffer: [8192]u8 = undefined;

var message: ?[]const u8 = null;

pub fn getErrorMessage() []const u8 {
    if (message) |msg| {
        message = null;
        return msg;
    } else {
        @panic("no error message");
    }
}

pub fn loadCompileErrorMessage(handle: gl.GLuint) void {
    if (message != null) {
        @panic("message must null");
    }

    var size: gl.GLsizei = undefined;
    gl.getShaderInfoLog(handle, @intCast(c_int, error_buffer.len), &size, @ptrCast([*c]gl.GLchar, &error_buffer[0]));
    message = error_buffer[0..@intCast(usize, size)];
}

pub fn loadLinkErrorMessage(handle: gl.GLuint) void {
    if (message != null) {
        @panic("message must null");
    }

    var size: gl.GLsizei = undefined;
    gl.getProgramInfoLog(handle, @intCast(c_int, error_buffer.len), &size, @ptrCast([*c]gl.GLchar, &error_buffer[0]));
    message = error_buffer[0..@intCast(usize, size)];
}
