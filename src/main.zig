const std = @import("std");
const c = @import("c.zig");
const gl = @import("gl.zig");
const lag = @import("lag.zig");
const Window = @import("window.zig").Window;
const Shader = @import("shader.zig").Shader;
const Texture = @import("texture.zig").Texture;
const sprite = @import("sprite.zig");

const Quad = gl.Quad;
const Vertex = gl.Vertex;
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const Animation = sprite.Animation;
const Sprite = sprite.Sprite;
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

    const telly_src: []const u8 = @embedFile("../assets/telly.png");
    _ = try Texture.from_memory(telly_src);

    shader.setInt("tex", 0);

    const frames = [_]Vec2{
        Vec2.init(1, 1),
        Vec2.init(18, 1),
        Vec2.init(35, 1),
        Vec2.init(52, 1),
        Vec2.init(69, 1),
        Vec2.init(86, 1),
    };

    var animation = Animation.init(10, frames[0..]);
    const telly = Sprite.init(Vec3.init(200, 200, 0), 16, 24, Vec2.init(1, 1));
    var animated_telly = Sprite.with_anim(Vec3.init(200 - 32, 200, 0), 16, 24, animation);

    var quads = [_]Quad{
        telly.toQuad(),
        animated_telly.toQuad(),
    };

    var indices: [quads.len * 6]u32 = undefined;
    gl.makeIndices(quads[0..], &indices);

    var vao: u32 = undefined;
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    var vbo: u32 = undefined;
    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(Quad) * quads.len, &quads, c.GL_DYNAMIC_DRAW);

    const tex_offset = @sizeOf(Vec3);
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glVertexAttribPointer(1, 2, c.GL_UNSIGNED_INT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(*const c_void, tex_offset));
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);

    var ebo: u32 = undefined;
    c.glGenBuffers(1, &ebo);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * indices.len, &indices, c.GL_DYNAMIC_DRAW);

    c.glBindVertexArray(0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, 0);

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    // init timing
    var now: f64 = c.glfwGetTime();
    var prev_time: f64 = now;
    var delta: f64 = 0;

    while (!win.shouldClose()) {
        now = c.glfwGetTime();
        delta = now - prev_time;
        prev_time = now;

        gl.clear();
        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @sizeOf(Quad) * quads.len, &quads);
        c.glDrawElements(c.GL_TRIANGLES, indices.len, c.GL_UNSIGNED_INT, null);
        c.glBindVertexArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

        win.tick();
        animated_telly.tick(delta);
        quads[1] = animated_telly.toQuad();
    }
}
