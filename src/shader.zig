const std = @import("std");
const fs = std.fs;
const warn = std.debug.warn;

const c = @import("c.zig");

const ShaderError = error{
    VertexCompilationFailed,
    FragmentCompilationFailed,
    LinkingFailed,
};

// loadFile takes a buffer and returns a u8 slice. The return slice is taken from the buf, so there's no additional
// allocation but they share the same lifetime
fn loadFile(fname: []const u8, buf: []u8) anyerror![]u8 {
    const flags = fs.File.OpenFlags{
        .read = true,
    };

    var file = try fs.cwd().openFile(
        fname,
        flags,
    );
    defer file.close();

    const len = try file.readAll(buf);
    buf[len] = 0; // need to null terminate
    return buf[0 .. len + 1];
}

// cast loaded shader source code into the expected pointer type
fn srcCast(src: []const u8) [*c]const [*c]const u8 {
    return @ptrCast([*c]const [*c]const u8, &src);
}

pub const Shader = struct {
    id: u32,

    pub fn init(vert_src: []const u8, frag_src: []const u8) anyerror!Shader {
        var success: i32 = 0;
        var log_buf: [512]u8 = undefined;
        var log = @ptrCast([*c]u8, &log_buf);

        // load and compile the vertex shader
        var vert = c.glCreateShader(c.GL_VERTEX_SHADER);
        c.glShaderSource(vert, 1, srcCast(vert_src), null);
        c.glCompileShader(vert);
        c.glGetShaderiv(vert, c.GL_COMPILE_STATUS, &success);
        if (success != 1) {
            c.glGetShaderInfoLog(vert, 512, null, log);
            warn("Shader Log: {s}", .{log});
            return ShaderError.VertexCompilationFailed;
        }

        // load and compile the fragment shader
        var frag = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        c.glShaderSource(frag, 1, srcCast(frag_src), null);
        c.glCompileShader(frag);
        c.glGetShaderiv(frag, c.GL_COMPILE_STATUS, &success);
        if (success != 1) {
            c.glGetShaderInfoLog(frag, 512, null, log);
            warn("Shader Log: {s}", .{log});
            return ShaderError.FragmentCompilationFailed;
        }

        const program = c.glCreateProgram();
        c.glAttachShader(program, vert);
        c.glAttachShader(program, frag);
        c.glLinkProgram(program);
        c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
        if (success != 1) {
            c.glGetProgramInfoLog(program, 512, null, log);
            warn("Shader Log: {s}", .{log});
            return ShaderError.LinkingFailed;
        }

        // shaders are linked to the program now, don't need to keep them anymore
        c.glDeleteShader(vert);
        c.glDeleteShader(frag);

        return Shader{ .id = program };
    }

    pub fn use(self: Shader) void {
        c.glUseProgram(self.id);
    }

    // TODO (etate): Make this generic?
    pub fn setInt(self: Shader, name: [*]const u8, val: i32) void {
        self.use();
        c.glUniform1i(c.glGetUniformLocation(self.id, name), val);
    }
};
