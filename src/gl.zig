const c = @import("c.zig");

pub fn clear() void {
    c.glClearColor(100.0 / 255.0, 149.0 / 255.0, 237.0 / 255.0, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
}
