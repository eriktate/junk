const std = @import("std");
const c = @import("c.zig");

const WindowError = error{
    InitFailed,
    CreateFailed,
};

const Event = struct {};

pub const Window = struct {
    width: u16,
    height: u16,
    title: []const u8,
    win: *c.GLFWwindow,

    pub fn init(width: u16, height: u16, title: [*:0]const u8) WindowError!Window {
        var window = Window{
            .width = width,
            .height = height,
            .title = std.mem.span(title),
            .win = undefined,
        };

        if (c.glfwInit() != 1) {
            return WindowError.InitFailed;
        }

        // window hints
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        window.win = c.glfwCreateWindow(width, height, title, null, null) orelse return WindowError.CreateFailed;

        c.glfwMakeContextCurrent(window.win);
        c.glViewport(0, 0, width, height);

        return window;
    }

    pub fn shouldClose(self: Window) bool {
        const escape = c.glfwGetKey(self.win, c.GLFW_KEY_ESCAPE);
        return escape == c.GLFW_PRESS;
    }

    pub fn close(self: Window) void {
        c.glfwDestroyWindow(self.win);
        c.glfwTerminate();
    }

    pub fn tick(self: Window) void {
        c.glfwSwapBuffers(self.win);
        c.glfwPollEvents();
    }
};
