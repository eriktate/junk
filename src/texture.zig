const c = @import("c.zig");

const TexError = error{
    NotPng,
    NoData,
};

pub const Texture = struct {
    id: u32,
    width: i32,
    height: i32,
    nr_channels: i32,

    pub fn from_memory(buffer: []const u8) TexError!Texture {
        var tex: Texture = undefined;
        if (c.stbi_info_from_memory(buffer.ptr, @intCast(c_int, buffer.len), &tex.width, &tex.height, null) == 0) {
            return error.NotPng;
        }

        const data = c.stbi_load_from_memory(buffer.ptr, @intCast(c_int, buffer.len), &tex.width, &tex.height, &tex.nr_channels, 0);
        defer c.stbi_image_free(data);

        if (data == null) {
            return TexError.NoData;
        }

        c.glActiveTexture(c.GL_TEXTURE0);
        c.glGenTextures(1, &tex.id);
        c.glBindTexture(c.GL_TEXTURE_2D, tex.id);
        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, tex.width, tex.height, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, data);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glGenerateMipmap(c.GL_TEXTURE_2D);

        return tex;
    }
};
