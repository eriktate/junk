const std = @import("std");
const c = @import("c.zig");
const gl = @import("gl.zig");
const lag = @import("lag.zig");
const Window = @import("window.zig").Window;
const Shader = @import("shader.zig").Shader;
const Texture = @import("texture.zig").Texture;
const sprite = @import("sprite.zig");
const Controller = @import("controller.zig").Controller;
const BBox = @import("bbox.zig").BBox;
const Manager = @import("manager.zig").Manager;
const Debug = @import("debug.zig").Debug;

const Quad = gl.Quad;
const Vertex = gl.Vertex;
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const Animation = sprite.Animation;
const Sprite = sprite.Sprite;
const print = std.debug.print;

fn getCursorPos(win: *c.GLFWwindow) Vec3 {
    // get mouse pos
    var mouse_x: f64 = undefined;
    var mouse_y: f64 = undefined;
    c.glfwGetCursorPos(win, &mouse_x, &mouse_y);
    const mouse_pos = Vec3.init(@floatCast(f32, mouse_x), @floatCast(f32, mouse_y), 0);

    // get cursor pos
    var cursor_pos = mouse_pos;
    cursor_pos.x = @divTrunc(cursor_pos.x, 16);
    cursor_pos.y = @divTrunc(cursor_pos.y, 16);
    cursor_pos = cursor_pos.scale(16);

    return cursor_pos;
}

export fn mouseCallback(win: ?*c.GLFWwindow, button: c_int, action: c_int, _: c_int) void {
    if (button == c.GLFW_MOUSE_BUTTON_LEFT and action == c.GLFW_PRESS) {
        const cursor_pos = getCursorPos(win.?);
        print("Clicked the LMB at: {d}, {d}\n", .{ cursor_pos.x, cursor_pos.y });
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = &arena.allocator;

    var win = try Window.init(640, 640, "kaizo -- float");
    defer win.close();

    _ = c.glfwSetMouseButtonCallback(win.win, mouseCallback);
    const ctrl = Controller.init(&win);
    var mgr = try Manager.init(alloc, 500);

    const vs_src = @embedFile("../shaders/vs.glsl");
    const fs_src = @embedFile("../shaders/fs.glsl");
    const shader = try Shader.init(vs_src, fs_src);

    const debug_vs_src = @embedFile("../shaders/debug_vs.glsl");
    const debug_fs_src = @embedFile("../shaders/debug_fs.glsl");
    const debug_shader = try Shader.init(debug_vs_src, debug_fs_src);

    // set screen resolution uniforms for use in coordinate mapping
    // modifying this affects the "zoom" level
    shader.setUint("width", win.width);
    shader.setUint("height", win.height);
    debug_shader.setUint("width", win.width);
    debug_shader.setUint("height", win.height);

    // const telly_src = @embedFile("../assets/telly.png");
    // _ = try Texture.from_memory(telly_src);

    const tileset_src = @embedFile("../assets/wasteland.png");
    const tileset_tex = try Texture.from_memory(tileset_src);
    shader.setInt("tex", 0);

    const frames = [_]Vec2{
        Vec2.init(1, 1),
        Vec2.init(18, 1),
        Vec2.init(35, 1),
        Vec2.init(52, 1),
        Vec2.init(69, 1),
        Vec2.init(86, 1),
    };

    var animation = Animation.init(10, frames[0..]);

    const player = try mgr.add(Sprite.with_anim(Vec3.init(200 - 32, 200, 0), 16, 24, animation));
    _ = try mgr.add(Sprite.init(Vec3.init(200, 280, 0), 16, 24, Vec2.init(1, 1)));
    _ = try mgr.add(Sprite.init(Vec3.init(200 - 32, 264, 0), 16, 24, Vec2.init(104, 1)));
    _ = try mgr.add(Sprite.init(Vec3.init(0, 0, 0), tileset_tex.width, tileset_tex.height, Vec2.init(0, 0)));

    var vao: u32 = undefined;
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    var vbo: u32 = undefined;
    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, @sizeOf(Quad) * mgr.quads.items.len), mgr.quads.items.ptr, c.GL_DYNAMIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glVertexAttribPointer(1, 2, c.GL_UNSIGNED_INT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(*const c_void, @sizeOf(Vec3)));
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);

    var ebo: u32 = undefined;
    c.glGenBuffers(1, &ebo);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(c_long, @sizeOf(u32) * mgr.indices.items.len), mgr.indices.items.ptr, c.GL_DYNAMIC_DRAW);

    c.glBindVertexArray(0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, 0);

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    // init timing
    var now: f64 = c.glfwGetTime();
    var prev_time: f64 = now;
    var delta: f64 = 0;

    const grav: f64 = 3;
    var vspeed: f32 = 0;

    var debug = try Debug.init(alloc, 500);
    while (!win.shouldClose()) {
        // timings
        now = c.glfwGetTime();
        delta = now - prev_time;
        prev_time = now;

        const grounded = mgr.checkCollisionRelative(player, Vec3.init(0, 1, 0));
        if (!grounded) {
            vspeed += @floatCast(f32, grav * delta);
        }

        var move_vec = Vec3.init(0, vspeed, 0);

        // controll stuff
        if (ctrl.getRight()) {
            move_vec.x += 0.5;
        }

        if (ctrl.getLeft()) {
            move_vec.x -= 0.5;
        }

        if (ctrl.getJump()) {
            if (grounded) {
                vspeed = -1;
            }
        }

        // check for collisions on each dimension (keeps things smooth and slide-y)
        if (mgr.checkCollisionRelative(player, Vec3.init(move_vec.x, 0, 0))) {
            move_vec.x = 0;
        }

        if (mgr.checkCollisionRelative(player, Vec3.init(0, move_vec.y, 0))) {
            move_vec.y = 0;
            vspeed = 0;
        }

        _ = try mgr.move(player, move_vec);

        shader.use();
        gl.clear();
        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @intCast(c_long, @sizeOf(Quad) * mgr.quads.items.len), mgr.quads.items.ptr);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mgr.indices.items.len), c.GL_UNSIGNED_INT, null);

        // render debug artifacts
        debug_shader.use();
        const cursor_pos = getCursorPos(win.win);
        try debug.drawLine(cursor_pos.add(Vec3.init(0, 0, 0)), cursor_pos.add(Vec3.init(16, 0, 0)));
        try debug.drawLine(cursor_pos.add(Vec3.init(0, 0, 0)), cursor_pos.add(Vec3.init(0, 16, 0)));
        debug.draw();

        // reset bound resources
        c.glBindVertexArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

        win.tick();
        mgr.tick(delta);
    }
}
