const std = @import("std");
const c = @import("c.zig");
const lag = @import("lag.zig");
const Vec2 = lag.Vec2(u32);

const TexError = error{
    NotPng,
    NoData,
};

pub const Textures = enum(u32) {
    Telly,
    Wasteland,
    Lab,
};

fn setActiveTexture(tex: Textures) void {
    std.debug.print("Textures int value: {d}\n", .{@enumToInt(tex)});
    const base = @intCast(u32, c.GL_TEXTURE0);
    const active = base + @enumToInt(tex);
    c.glActiveTexture(active);
}

pub const Origin = struct {
    idx: Textures,
    pos: Vec2,

    pub fn init(idx: Textures, pos: Vec2) Origin {
        return Origin{
            .idx = idx,
            .pos = pos,
        };
    }

    pub fn eq(self: Origin, other: Origin) bool {
        return self.idx == other.idx and self.pos.eq(other.pos);
    }
};

// Atlas assumes 1px border/spacing between all frames/tiles
pub const Atlas = struct {
    texture: Texture,
    offset: Vec2,
    width: u32,
    height: u32,
    frame_width: u32,
    frame_height: u32,

    pub fn init(texture: Texture, offset: Vec2, frame_width: u32, frame_height: u32, width: u32, height: u32) Atlas {
        return Atlas{
            .texture = texture,
            .offset = offset,
            .width = width,
            .height = height,
            .frame_width = frame_width,
            .frame_height = frame_height,
        };
    }

    pub fn getFrame(self: Atlas, pos: Vec2) Origin {
        const x_offset = 1 + pos.x;
        const x_pos = pos.x * self.frame_width + x_offset;
        const y_offset = 1 + pos.y;
        const y_pos = pos.y * self.frame_height + y_offset;

        return Origin.init(self.texture.idx, Vec2.init(x_pos, y_pos));
    }
};

const Texture = @This();
id: u32,
idx: Textures,
width: u32,
height: u32,
nr_channels: i32,

pub fn fromMemory(idx: Textures, buffer: []const u8) TexError!Texture {
    var width: i32 = undefined;
    var height: i32 = undefined;

    var tex: Texture = undefined;
    tex.idx = idx;
    if (c.stbi_info_from_memory(buffer.ptr, @intCast(c_int, buffer.len), &width, &height, null) == 0) {
        return error.NotPng;
    }

    const data = c.stbi_load_from_memory(buffer.ptr, @intCast(c_int, buffer.len), &width, &height, &tex.nr_channels, 0);
    defer c.stbi_image_free(data);

    tex.width = @intCast(u32, width);
    tex.height = @intCast(u32, height);

    if (data == null) {
        return TexError.NoData;
    }

    c.glGenTextures(1, &tex.id);
    setActiveTexture(tex.idx);
    c.glBindTexture(c.GL_TEXTURE_2D, tex.id);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, width, height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, data);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    return tex;
}

pub fn makeAtlas(self: Texture, offset: Vec2, frame_width: u32, frame_height: u32, opt_width: ?u32, opt_height: ?u32) Atlas {
    var w: u32 = self.width;
    var h: u32 = self.height;
    if (opt_width) |width| {
        w = width;
    }

    if (opt_height) |height| {
        h = height;
    }

    return Atlas.init(self, offset, frame_width, frame_height, w, h);
}
