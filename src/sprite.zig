const std = @import("std");
const lag = @import("lag.zig");
const gl = @import("gl.zig");
const BBox = @import("bbox.zig");
const Texture = @import("texture.zig").Texture;

const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const Quad = gl.Quad;
const Vertex = gl.Vertex;

pub const Tex = struct {
    id: u32,
    pos: Vec2,

    pub fn init(id: u32, pos: Vec2) Tex {
        return Tex{
            .id = id,
            .pos = pos,
        };
    }

    pub fn eq(self: Tex, other: Tex) bool {
        return self.id == other.id and self.pos.eq(other.pos);
    }
};

pub const Animation = struct {
    current_frame: f32,
    frame_rate: f32,
    frame_width: u32,
    frame_height: u32,
    texture: Texture,
    frames: []const Vec2, // slice of top-left-corner tex coords. width/height determined by the owning sprite

    pub fn init(frame_rate: f32, frame_width: u32, frame_height: u32, texture: Texture, frames: []const Vec2) Animation {
        return Animation{
            .current_frame = 0,
            .frame_rate = frame_rate,
            .frames = frames,
            .frame_width = frame_width,
            .frame_height = frame_height,
            .texture = texture,
        };
    }

    pub fn tick(self: *Animation, delta: f64) void {
        self.current_frame += @floatCast(f32, self.frame_rate * delta);
        const f_len = @intToFloat(f32, self.frames.len);
        if (self.current_frame > f_len) {
            self.current_frame -= f_len;
        }
    }

    pub fn getFrame(self: Animation) Tex {
        return Tex.init(self.texture.id, self.frames[@floatToInt(usize, self.current_frame)]);
    }

    pub fn fromGridPos(self: Animation, pos: Vec2) Vec2 {
        const x_offset = 1 + pos.x;
        const x_pos = pos.x * self.frame_width + x_offset;
        const y_offset = 1 + pos.y;
        const y_pos = pos.y * self.frame_height + y_offset;

        return Vec2.init(x_pos, y_pos);
    }
};

pub const ShowTag = enum {
    tex,
    anim,
};

pub const Show = union(ShowTag) {
    tex: Tex,
    anim: Animation,
};

pub const Sprite = struct {
    id: usize,
    pos: Vec3,
    width: u32,
    height: u32,
    x_scale: f32,
    y_scale: f32,
    flipped: bool,
    show: Show,

    pub fn init(pos: Vec3, width: u32, height: u32, tex: Tex) Sprite {
        return Sprite{
            .id = 0,
            .pos = pos,
            .width = width,
            .height = height,
            .x_scale = 1,
            .y_scale = 1,
            .flipped = false,
            .show = Show{ .tex = tex },
        };
    }

    pub fn withAnim(pos: Vec3, width: u32, height: u32, anim: Animation) Sprite {
        return Sprite{
            .id = 0,
            .pos = pos,
            .width = width,
            .height = height,
            .x_scale = 1,
            .y_scale = 1,
            .flipped = false,
            .show = Show{ .anim = anim },
        };
    }

    pub fn setTexture(self: *Sprite, tex: Vec2) void {
        self.show = Show{ .tex = tex };
    }

    pub fn setAnimation(self: *Sprite, anim: Animation) void {
        self.show = Show{ .anim = anim };
    }

    pub fn setFlipped(self: *Sprite, flipped: bool) void {
        self.flipped = flipped;
    }

    pub fn toQuad(self: Sprite) Quad {
        const f_width: f32 = @intToFloat(f32, self.width);
        const f_height: f32 = @intToFloat(f32, self.height);
        var tex: Tex = undefined;
        switch (self.show) {
            ShowTag.tex => |t| tex = t,
            ShowTag.anim => |anim| tex = anim.getFrame(),
        }

        var quad = Quad{
            .tr = Vertex.init(Vec3.init(self.pos.x + f_width, self.pos.y, self.pos.z), Vec2.init(tex.pos.x + self.width, tex.pos.y), tex.id),
            .tl = Vertex.init(self.pos, tex.pos, tex.id),
            .bl = Vertex.init(Vec3.init(self.pos.x, self.pos.y + f_height, self.pos.z), Vec2.init(tex.pos.x, tex.pos.y + self.height), tex.id),
            .br = Vertex.init(self.pos.add(Vec3.init(f_width, f_height, 0)), tex.pos.add(Vec2.init(self.width, self.height)), tex.id),
        };

        if (self.flipped) {
            const tl = quad.tl.tex_pos;
            const bl = quad.bl.tex_pos;
            quad.tl.tex_pos = quad.tr.tex_pos;
            quad.bl.tex_pos = quad.br.tex_pos;
            quad.tr.tex_pos = tl;
            quad.br.tex_pos = bl;
        }

        return quad;
    }

    pub fn makeBBox(self: Sprite) BBox {
        return BBox.init(self.id, self.pos, self.width, self.height);
    }

    pub fn tick(self: *Sprite, delta: f64) void {
        switch (self.show) {
            ShowTag.tex => return,
            ShowTag.anim => |*anim| anim.tick(delta),
        }
    }

    pub fn getTex(self: Sprite) Vec2 {
        switch (self.show) {
            ShowTag.tex => |tex| return tex.pos,
            ShowTag.anim => |anim| return anim.getFrame().pos,
        }
    }
};
