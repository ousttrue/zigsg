const std = @import("std");
const zigla = @import("zigla");
const glo = @import("glo");
const gltf = @import("./gltf.zig");
const vs = @embedFile("./mvp.vs");
const fs = @embedFile("./mvp.fs");
const scene_loader = @import("./scene_loader.zig");

pub const MeshResource = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    builder: *scene_loader.Builder,
    shader: ?glo.Shader = null,
    vao: ?glo.Vao = null,
    draw_count: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, builder: *scene_loader.Builder) Self {
        return Self{
            .allocator = allocator,
            .builder = builder,
        };
    }

    pub fn deinit(self: *Self) void {
        self.builder.delete();
    }

    pub fn render(self: *Self, camera: *zigla.Camera, light: zigla.Vec4, world: zigla.Mat4) void {
        if (self.shader == null) {
            var shader = glo.Shader.load(self.allocator, vs, fs) catch {
                std.debug.print("{s}\n", .{glo.getErrorMessage()});
                @panic("load");
            };
            self.shader = shader;
        }

        if (self.shader) |*shader| {
            var vbo = glo.Vbo.init();
            const vertices = self.builder.getVertices();
            vbo.setVertices(scene_loader.Vertex, vertices, false);
            if (self.vao) |*vao| {
                vao.deinit();
            }

            if (self.builder.getIndices()) |indices| {
                var ibo = glo.Ibo.init();
                ibo.setIndices(u32, indices, false);
                self.draw_count = @intCast(u32, indices.len);
                self.vao = glo.Vao.init(vbo, shader.createVertexLayout(self.allocator), ibo);
            } else {
                self.draw_count = @intCast(u32, vertices.len);
                self.vao = glo.Vao.init(vbo, shader.createVertexLayout(self.allocator), null);
            }
        }

        if (self.shader) |*shader| {
            shader.use();
            defer shader.unuse();

            shader.setMat4("uMVP", &world.mul(camera.getViewProjectionMatrix())._0.x);
            shader.setMat4("uView", &camera.view.getViewMatrix()._0.x);
            shader.setVec4("uLight", &light.x);
            if (self.vao) |vao| {
                vao.draw(self.draw_count, .{});
            }
        }
    }
};

pub const Node = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    name: []const u8,
    transform: zigla.Transform = .identity,
    children: std.ArrayList(*Node),
    mesh: ?*MeshResource = null,

    pub fn init(allocator: std.mem.Allocator, i: usize, _name: ?[]const u8) Self {
        return Self{
            .allocator = allocator,
            .name = if (_name) |name| (allocator.dupe(u8, name) catch unreachable) else (std.fmt.allocPrint(allocator, "{}", .{i}) catch unreachable),
            .children = std.ArrayList(*Node).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
        self.allocator.free(self.name);
    }

    pub fn addChild(self: *Self, child: *Node) void {
        self.children.append(child) catch unreachable;
    }

    pub fn render(self: *Self, camera: *zigla.Camera, light: zigla.Vec4, parent: zigla.Mat4) void {
        const world = self.transform.toMat4().mul(parent);
        if (self.mesh) |mesh| {
            mesh.render(camera, light, world);
        }
        for (self.children.items) |child| {
            child.render(camera, light, world);
        }
    }
};

pub const Model = struct {
    const Self = @This();

    resources: std.ArrayList(MeshResource),
    nodes: std.ArrayList(Node),
    roots: std.ArrayList(*Node),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .resources = std.ArrayList(MeshResource).init(allocator),
            .nodes = std.ArrayList(Node).init(allocator),
            .roots = std.ArrayList(*Node).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.roots.deinit();
        for (self.nodes.items) |*n| {
            n.deinit();
        }
        self.nodes.deinit();
        for (self.resources.items) |*r| {
            r.deinit();
        }
        self.resource.deinit();
    }

    pub fn load(allocator: std.mem.Allocator, path: []const u8) ?Self {
        var self = Self.init(allocator);
        const data = scene_loader.readsource(allocator, path) catch |err| {
            std.debug.print("readsource: {s}", .{@errorName(err)});
            return null;
        };
        defer allocator.free(data);
        std.debug.print("{}bytes\n", .{data.len});

        const glb = gltf.Glb.parse(data) catch |err| {
            std.debug.print("Glb.parse: {s}", .{@errorName(err)});
            return null;
        };
        std.debug.print("parse glb\n", .{});

        var stream = std.json.TokenStream.init(glb.jsonChunk);
        const options = std.json.ParseOptions{ .allocator = allocator, .ignore_unknown_fields = true };
        @setEvalBranchQuota(2000);
        const parsed = std.json.parse(gltf.Gltf, &stream, options) catch |err| {
            std.debug.print("json.parse: {s}", .{@errorName(err)});
            return null;
        };
        defer std.json.parseFree(gltf.Gltf, parsed, options);
        std.debug.print("{} meshes\n", .{parsed.meshes.len});

        const reader = gltf.GtlfBufferReader{
            .buffers = &.{glb.binChunk},
            .bufferViews = parsed.bufferViews,
            .accessors = parsed.accessors,
        };

        for (parsed.meshes) |*gltf_mesh, i| {
            std.debug.print("mesh#{}: {} prims\n", .{ i, gltf_mesh.primitives.len });

            var vertex_count: usize = 0;
            var index_count: usize = 0;
            for (gltf_mesh.primitives) |*prim| {
                vertex_count += parsed.accessors[prim.attributes.POSITION].count;
                index_count += parsed.accessors[prim.indices.?].count;
            }

            var builder = scene_loader.Builder.new(allocator);
            builder.vertices.resize(vertex_count) catch unreachable;
            builder.indices.resize(index_count) catch unreachable;

            var vertex_offset: usize = 0;
            var index_offset: usize = 0;
            for (gltf_mesh.primitives) |*prim| {
                // join submeshes
                std.debug.print("POSITIONS={any}, indices={any}\n", .{ prim.indices, prim.attributes.POSITION });

                const indices_accessor = parsed.accessors[prim.indices.?];
                reader.getUIntIndicesFromAccessor(prim.indices.?, builder.indices.items[index_offset .. index_offset + indices_accessor.count], vertex_offset);

                const position = reader.getTypedFromAccessor(zigla.Vec3, prim.attributes.POSITION);
                const normal = reader.getTypedFromAccessor(zigla.Vec3, prim.attributes.NORMAL.?);
                for (position) |v, j| {
                    var dst = &builder.vertices.items[j + vertex_offset];
                    dst.position = v;
                    dst.normal = normal[j];
                    dst.color = zigla.Vec3.values(1, 1, 1);
                }

                index_offset += indices_accessor.count;
                vertex_offset += position.len;
            }

            self.resources.append(MeshResource.init(allocator, builder)) catch unreachable;
        }

        for (parsed.nodes) |*gltf_node, i| {
            var node = Node.init(allocator, i, gltf_node.name);
            std.debug.print("[{}] {s}\n", .{ i, node.name });
            if (gltf_node.matrix) |m| {
                node.transform = .{ .mat4 = @bitCast(zigla.Mat4, m) };
            } else {
                node.transform = .{ .trs = .{
                    .translation = @bitCast(zigla.Vec3, gltf_node.translation),
                    .rotation = .{ .quaternion = @bitCast(zigla.Quaternion, gltf_node.rotation) },
                    .scale = .{ .vec3 = @bitCast(zigla.Vec3, gltf_node.scale) },
                } };
            }
            if (gltf_node.mesh) |mesh_index| {
                node.mesh = &self.resources.items[@intCast(usize, mesh_index)];
            }
            self.nodes.append(node) catch unreachable;
        }

        // build tree
        for (parsed.nodes) |*gltf_node, i| {
            var node = &self.nodes.items[i];
            for (gltf_node.children) |child_index| {
                var child = &self.nodes.items[@intCast(usize, child_index)];
                node.addChild(child);
            }
        }

        const gltf_scene = parsed.scenes[0];
        for (gltf_scene.nodes) |root_index| {
            self.roots.append(&self.nodes.items[@intCast(usize, root_index)]) catch unreachable;
        }

        return self;
    }

    pub fn render(self: *Self, camera: *zigla.Camera, light: zigla.Vec4) void {
        for (self.roots.items) |node| {
            node.render(camera, light, .{});
        }
    }
};
