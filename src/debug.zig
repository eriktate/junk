const std = @import("std");
const c = @import("c.zig");
const lag = @import("lag.zig");

const Shader = @import("shader.zig");
const Vertex = @import("gl.zig").Vertex;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);

const Debug = @This();
vertices: ArrayList(Vertex),
shader: Shader,
active: bool,
vao: u32,
vbo: u32,

pub fn init(alloc: Allocator, cap: u64, shader: Shader) !Debug {
    var vertices = ArrayList(Vertex).init(alloc);

    try vertices.ensureTotalCapacity(cap);

    var debug = Debug{
        .vertices = vertices,
        .shader = shader,
        .vao = undefined,
        .vbo = undefined,
        .active = false,
    };

    c.glGenVertexArrays(1, &debug.vao);
    c.glBindVertexArray(debug.vao);

    c.glGenBuffers(1, &debug.vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, debug.vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, @sizeOf(Vertex) * debug.vertices.items.len), debug.vertices.items.ptr, c.GL_DYNAMIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glVertexAttribPointer(1, 2, c.GL_UNSIGNED_INT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(*const anyopaque, @sizeOf(Vec3)));
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);
    c.glBindVertexArray(0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

    return debug;
}

pub fn drawLine(self: *Debug, start: Vec3, end: Vec3) !void {
    const start_vert = Vertex.init(start, Vec2.zero(), 0);
    const end_vert = Vertex.init(end, Vec2.zero(), 0);
    try self.vertices.append(start_vert);
    try self.vertices.append(end_vert);
}

pub fn draw(self: *Debug) void {
    if (!self.active) {
        return;
    }

    self.shader.use();
    c.glBindVertexArray(self.vao);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, @sizeOf(Vertex) * self.vertices.items.len), self.vertices.items.ptr, c.GL_DYNAMIC_DRAW);
    c.glDrawArrays(c.GL_LINES, 0, @intCast(c_int, self.vertices.items.len));
    self.vertices.resize(0) catch unreachable;
}

pub fn toggle(self: *Debug) void {
    self.active = !self.active;
}
