const std = @import("std");
const c = @import("c.zig");

const gl = @import("gl.zig");
const Window = @import("window.zig").Window;
const Shader = @import("shader.zig").Shader;
const Texture = @import("texture.zig").Texture;
const print = std.debug.print;

const Vertex = struct {
    x: f32,
    y: f32,
    z: f32,
    tex_x: f32,
    tex_y: f32,
};

pub fn main() anyerror!void {
    var win = try Window.init(640, 640, "kaizo -- float");
    defer win.close();

    const vs_src = @embedFile("../shaders/vs.glsl");
    const fs_src = @embedFile("../shaders/fs.glsl");
    const shader = try Shader.init(vs_src, fs_src);
    shader.use();

    // const dino_src: []const u8 = @embedFile("../assets/dino-export.png");
    const dino_src: []const u8 = @embedFile("../assets/dino.png");
    _ = try Texture.from_memory(dino_src);

    shader.setInt("tex", 0);

    const vertices = [4]Vertex{ Vertex{
        .x = 0.5,
        .y = 0.5,
        .z = 0.0,
        .tex_x = 1,
        .tex_y = 0,
    }, Vertex{ .x = -0.5, .y = 0.5, .z = 0.0, .tex_x = 0, .tex_y = 0 }, Vertex{
        .x = -0.5,
        .y = -0.5,
        .z = 0.0,
        .tex_x = 0,
        .tex_y = 1,
    }, Vertex{
        .x = 0.5,
        .y = -0.5,
        .z = 0.0,
        .tex_x = 1,
        .tex_y = 1,
    } };

    const indices = [6]u32{
        0, 1, 2,
        2, 3, 0,
    };

    var vao: u32 = undefined;
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    var vbo: u32 = undefined;
    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(Vertex) * vertices.len, &vertices, c.GL_STATIC_DRAW);

    const tex_offset = 3 * @sizeOf(f32);
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(*const c_void, tex_offset));
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);

    var ebo: u32 = undefined;
    c.glGenBuffers(1, &ebo);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * indices.len, &indices, c.GL_STATIC_DRAW);

    c.glBindVertexArray(0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, 0);

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    while (!win.shouldClose()) {
        gl.clear();
        c.glBindVertexArray(vao);
        c.glDrawElements(c.GL_TRIANGLES, indices.len, c.GL_UNSIGNED_INT, null);
        c.glBindVertexArray(0);
        win.tick();
    }
}