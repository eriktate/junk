const c = @import("c.zig");
const lag = @import("lag.zig");
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);

pub const Vertex = struct {
    pos: Vec3,
    tex_pos: Vec2,

    pub fn init(pos: Vec3, tex_pos: Vec2) Vertex {
        return Vertex{
            .pos = pos,
            .tex_pos = tex_pos,
        };
    }
};

pub const Quad = struct {
    tr: Vertex,
    tl: Vertex,
    bl: Vertex,
    br: Vertex,
};

pub fn makeIndices(quads: []const Quad, indices: [*]u32) void {
    for (quads) |_, i| {
        const idx = @intCast(u32, i);
        indices[6 * idx] = 6 * idx;
        indices[6 * idx + 1] = 6 * idx + 1;
        indices[6 * idx + 2] = 6 * idx + 2;
        indices[6 * idx + 3] = 6 * idx + 2;
        indices[6 * idx + 4] = 6 * idx + 3;
        indices[6 * idx + 5] = 6 * idx;
    }
}

pub fn clear() void {
    c.glClearColor(100.0 / 255.0, 149.0 / 255.0, 237.0 / 255.0, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
}
