const fbo = @import("./fbo.zig");
const vao = @import("./vao.zig");
const shader_program = @import("./shader_program.zig");
const texture = @import("./texture.zig");
const error_handling = @import("./error_handling.zig");

pub const Texture = texture.Texture;
pub const FboManager = fbo.FboManager;
pub const Shader = shader_program.Shader;
pub const UniformLocation = shader_program.UniformLocation;
pub const UniformBlockIndex = shader_program.UniformBlockIndex;
pub const Vbo = vao.Vbo;
pub const Ibo = vao.Ibo;
pub const Vao = vao.Vao;
pub const getErrorMessage = error_handling.getErrorMessage;
