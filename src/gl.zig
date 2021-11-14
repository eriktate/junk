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

    pub fn eq(self: Vertex, other: Vertex) bool {
        return self.pos.eq(other.pos) and self.tex_pos.eq(other.tex_pos);
    }
};

pub const Quad = struct {
    tr: Vertex,
    tl: Vertex,
    bl: Vertex,
    br: Vertex,

    pub fn zero() Quad {
        return Quad{
            .tr = Vertex.init(Vec3.zero(), Vec2.zero()),
            .tl = Vertex.init(Vec3.zero(), Vec2.zero()),
            .bl = Vertex.init(Vec3.zero(), Vec2.zero()),
            .br = Vertex.init(Vec3.zero(), Vec2.zero()),
        };
    }

    pub fn eq(self: Quad, other: Quad) bool {
        return self.tr.eq(other.tr) and self.tl.eq(other.tl) and self.bl.eq(other.bl) and self.br.eq(other.br);
    }
};

pub fn makeIndices(quads: []const Quad, indices: [*]u32) void {
    for (quads) |_, i| {
        const idx = @intCast(u32, i);
        indices[6 * idx] = 4 * idx;
        indices[6 * idx + 1] = 4 * idx + 1;
        indices[6 * idx + 2] = 4 * idx + 2;
        indices[6 * idx + 3] = 4 * idx + 2;
        indices[6 * idx + 4] = 4 * idx + 3;
        indices[6 * idx + 5] = 4 * idx;
    }
}

pub fn clear() void {
    c.glClearColor(100.0 / 255.0, 149.0 / 255.0, 237.0 / 255.0, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
}
