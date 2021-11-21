const std = @import("std");
const c = @import("c.zig");

const TexError = error{
    NotPng,
    NoData,
};

fn setActiveTexture(id: u32) void {
    switch (id) {
        1 => c.glActiveTexture(c.GL_TEXTURE0),
        2 => c.glActiveTexture(c.GL_TEXTURE1),
        3 => c.glActiveTexture(c.GL_TEXTURE2),
        4 => c.glActiveTexture(c.GL_TEXTURE3),
        5 => c.glActiveTexture(c.GL_TEXTURE4),
        6 => c.glActiveTexture(c.GL_TEXTURE5),
        else => c.glActiveTexture(c.GL_TEXTURE0),
    }
}

const Texture = @This();
id: u32,
width: u32,
height: u32,
nr_channels: i32,

pub fn fromMemory(buffer: []const u8) TexError!Texture {
    var width: i32 = undefined;
    var height: i32 = undefined;

    var tex: Texture = undefined;
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
    setActiveTexture(tex.id);
    c.glBindTexture(c.GL_TEXTURE_2D, tex.id);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, width, height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, data);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    return tex;
}
