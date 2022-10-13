const std = @import("std");
const gl = @import("gl");
const imgui = @import("imgui");
const Texture = @import("./texture.zig").Texture;

pub const Fbo = struct {
    const Self = @This();

    texture: Texture,
    handle: [1]gl.GLuint = .{0},
    depth: [1]gl.GLuint = .{0},

    fn _init(self: *Self, width: c_int, height: c_int, useDepth: bool) void {
        gl.genFramebuffers(self.handle.len, &self.handle[0]);
        if (useDepth) {
            gl.genRenderbuffers(self.depth.len, &self.depth[0]);
        }
        self.bind();
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.texture.handle, 0);
        const drawBuffers = [1]gl.GLuint{gl.COLOR_ATTACHMENT0};
        gl.drawBuffers(drawBuffers.len, &drawBuffers[0]);
        if (useDepth) {
            gl.bindRenderbuffer(gl.RENDERBUFFER, self.depth[0]);
            gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT, width, height);
            gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, self.depth[0]);
        }
        self.unbind();
    }

    pub fn init(width: c_int, height: c_int, use_depth: bool) Fbo {
        var self = Fbo{
            .texture = Texture.init(width, height, gl.RGBA, null),
        };
        self._init(width, height, use_depth);
        // LOGGER.debug(f'fbo: {self.fbo}, texture: {self.texture}, depth: {self.depth}')
        return self;
    }

    pub fn deinit(self: *const Self) void {
        // LOGGER.debug(f'fbo: {self.fbo}')
        gl.deleteFramebuffers(1, &self.handle);
        gl.deleteRenderbuffers(1, &self.depth);
    }

    pub fn bind(self: *const Self) void {
        gl.bindFramebuffer(gl.FRAMEBUFFER, self.handle[0]);
    }

    pub fn unbind(self: *const Self) void {
        _ = self;
        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
    }
};

pub const FboManager = struct {
    const Self = @This();

    fbo: ?Fbo = null,

    pub fn unbind(self: *Self) void {
        if (self.fbo) |fbo| {
            fbo.unbind();
        }
    }

    pub fn clear(self: *Self, width: c_int, height: c_int, color: *const [4]f32) ?*anyopaque {
        if (width == 0 or height == 0) {
            return null;
        }

        if (self.fbo) |fbo| {
            if (fbo.texture.width != width or fbo.texture.height != height) {
                fbo.deinit();
                self.fbo = null;
            }
        }
        if (self.fbo == null) {
            self.fbo = Fbo.init(width, height, true);
        }
        std.debug.assert(self.fbo.?.texture.handle != 0);

        if (self.fbo) |fbo| {
            fbo.bind();
            gl.viewport(0, 0, width, height);
            gl.scissor(0, 0, width, height);
            gl.clearColor(color[0] * color[3], color[1] * color[3], color[2] * color[3], color[3]);
            gl.clearDepth(1.0);
            gl.depthFunc(gl.LESS);
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            return @intToPtr(*anyopaque, fbo.texture.handle);
        }

        unreachable;
    }
};
