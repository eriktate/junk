const lag = @import("lag.zig");
const gl = @import("gl.zig");

const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const Quad = gl.Quad;
const Vertex = gl.Vertex;

pub const Sprite = struct {
    pos: Vec3,
    width: u32,
    height: u32,
    tex_coord: Vec2,

    pub fn init(pos: Vec3, width: u32, height: u32, tex_coord: Vec2) Sprite {
        return Sprite{
            .pos = pos,
            .width = width,
            .height = height,
            .tex_coord = tex_coord,
        };
    }

    pub fn toQuad(self: Sprite) Quad {
        const f_width: f32 = @intToFloat(f32, self.width);
        const f_height: f32 = @intToFloat(f32, self.height);
        return Quad{
            .tr = Vertex.init(Vec3.init(self.pos.x + f_width, self.pos.y, self.pos.z), Vec2.init(self.tex_coord.x + self.width, self.tex_coord.y)),
            .tl = Vertex.init(self.pos, self.tex_coord),
            .bl = Vertex.init(Vec3.init(self.pos.x, self.pos.y + f_height, self.pos.z), Vec2.init(self.tex_coord.x, self.tex_coord.y + self.height)),
            .br = Vertex.init(self.pos.add(Vec3.init(f_width, f_height, 0)), self.tex_coord.add(Vec2.init(self.width, self.height))),
        };
    }
};
