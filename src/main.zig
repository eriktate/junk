const std = @import("std");
const c = @import("c.zig");
const gl = @import("gl.zig");
const lag = @import("lag.zig");
const Window = @import("window.zig").Window;
const Shader = @import("shader.zig").Shader;
const Texture = @import("texture.zig").Texture;
const Sprite = @import("sprite.zig").Sprite;

const Quad = gl.Quad;
const Vertex = gl.Vertex;
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const print = std.debug.print;

pub fn main() anyerror!void {
    var win = try Window.init(640, 640, "kaizo -- float");
    defer win.close();

    const vs_src = @embedFile("../shaders/vs.glsl");
    const fs_src = @embedFile("../shaders/fs.glsl");
    const shader = try Shader.init(vs_src, fs_src);
    shader.use();

    // set screen resolution uniforms for use in coordinate mapping
    // modifying this affects the "zoom" level
    shader.setUint("width", win.width / 2);
    shader.setUint("height", win.height / 2);

    const dino_src: []const u8 = @embedFile("../assets/dino.png");
    _ = try Texture.from_memory(dino_src);

    shader.setInt("tex", 0);

    const dino = Sprite.init(Vec3.init(200, 200, 0), 16, 16, Vec2.init(0, 0));
    var other_dino = dino;
    other_dino.pos = other_dino.pos.add(Vec3.init(-32, 0, 0));

    const quads = [_]Quad{
        dino.toQuad(),
        other_dino.toQuad(),
    };

    var indices: [quads.len * 6]u32 = undefined;
    gl.makeIndices(quads[0..], &indices);

    var vao: u32 = undefined;
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    var vbo: u32 = undefined;
    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(Quad) * quads.len, &quads, c.GL_STATIC_DRAW);

    const tex_offset = @sizeOf(Vec3);
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glVertexAttribPointer(1, 2, c.GL_UNSIGNED_INT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(*const c_void, tex_offset));
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
