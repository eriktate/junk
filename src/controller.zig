const c = @import("c.zig");
const Window = @import("window.zig");

const Controller = @This();
win: *Window,

pub fn init(win: *Window) Controller {
    return Controller{
        .win = win,
    };
}

pub fn getRight(self: Controller) bool {
    return self.win.getKey(c.GLFW_KEY_D);
}

pub fn getLeft(self: Controller) bool {
    return self.win.getKey(c.GLFW_KEY_A);
}

pub fn getJump(self: Controller) bool {
    return self.win.getKey(c.GLFW_KEY_W);
}
