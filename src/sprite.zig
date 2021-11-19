const std = @import("std");
const lag = @import("lag.zig");
const gl = @import("gl.zig");
const BBox = @import("bbox.zig");

const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const Quad = gl.Quad;
const Vertex = gl.Vertex;

pub const Animation = struct {
    current_frame: f32,
    frame_rate: f32,
    frames: []const Vec2, // slice of top-left-corner tex coords. width/height determined by the owning sprite

    pub fn init(frame_rate: f32, frames: []const Vec2) Animation {
        return Animation{
            .current_frame = 0,
            .frame_rate = frame_rate,
            .frames = frames,
        };
    }

    pub fn tick(self: *Animation, delta: f64) void {
        self.current_frame += @floatCast(f32, self.frame_rate * delta);
        const f_len = @intToFloat(f32, self.frames.len);
        if (self.current_frame > f_len) {
            self.current_frame -= f_len;
        }
    }

    pub fn getFrame(self: Animation) Vec2 {
        return self.frames[@floatToInt(usize, self.current_frame)];
    }
};

pub const ShowTag = enum {
    tex,
    anim,
};

pub const Show = union(ShowTag) {
    tex: Vec2,
    anim: Animation,
};

pub const Sprite = struct {
    id: usize,
    pos: Vec3,
    width: u32,
    height: u32,
    x_scale: f32,
    y_scale: f32,
    show: Show,

    pub fn init(pos: Vec3, width: u32, height: u32, tex: Vec2) Sprite {
        return Sprite{
            .id = 0,
            .pos = pos,
            .width = width,
            .height = height,
            .x_scale = 1,
            .y_scale = 1,
            .show = Show{ .tex = tex },
        };
    }

    pub fn with_anim(pos: Vec3, width: u32, height: u32, anim: Animation) Sprite {
        return Sprite{
            .id = 0,
            .pos = pos,
            .width = width,
            .height = height,
            .x_scale = 1,
            .y_scale = 1,
            .show = Show{ .anim = anim },
        };
    }

    pub fn set_texture(self: *Sprite, tex: Vec2) void {
        self.show = Show{ .tex = tex };
    }

    pub fn set_animation(self: *Sprite, anim: Animation) void {
        self.show = Show{ .anim = anim };
    }

    pub fn toQuad(self: Sprite) Quad {
        const f_width: f32 = @intToFloat(f32, self.width);
        const f_height: f32 = @intToFloat(f32, self.height);
        var tex: Vec2 = undefined;
        switch (self.show) {
            ShowTag.tex => |t| tex = t,
            ShowTag.anim => |anim| tex = anim.getFrame(),
        }

        return Quad{
            .tr = Vertex.init(Vec3.init(self.pos.x + f_width, self.pos.y, self.pos.z), Vec2.init(tex.x + self.width, tex.y)),
            .tl = Vertex.init(self.pos, tex),
            .bl = Vertex.init(Vec3.init(self.pos.x, self.pos.y + f_height, self.pos.z), Vec2.init(tex.x, tex.y + self.height)),
            .br = Vertex.init(self.pos.add(Vec3.init(f_width, f_height, 0)), tex.add(Vec2.init(self.width, self.height))),
        };
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
            ShowTag.tex => |tex| return tex,
            ShowTag.anim => |anim| return anim.getFrame(),
        }
    }
};
