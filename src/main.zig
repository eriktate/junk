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
const LevelEditor = @import("level_editor.zig").LevelEditor;

const Quad = gl.Quad;
const Vertex = gl.Vertex;
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const Animation = sprite.Animation;
const Sprite = sprite.Sprite;
const print = std.debug.print;

var level_editor: LevelEditor = undefined;

export fn mouseCallback(_: ?*c.GLFWwindow, button: c_int, action: c_int, _: c_int) void {
    if (button == c.GLFW_MOUSE_BUTTON_LEFT) {
        if (action == c.GLFW_PRESS) {
            level_editor.handleLMB(true);
        }

        if (action == c.GLFW_RELEASE) {
            level_editor.handleLMB(false);
        }
    }

    if (button == c.GLFW_MOUSE_BUTTON_RIGHT) {
        if (action == c.GLFW_PRESS) {
            level_editor.handleRMB(true);
        }

        if (action == c.GLFW_RELEASE) {
            level_editor.handleRMB(false);
        }
    }
}

export fn keyCallback(_: ?*c.GLFWwindow, key: c_int, _: c_int, action: c_int, _: c_int) void {
    if (key == c.GLFW_KEY_TAB and action == c.GLFW_PRESS) {
        level_editor.toggleMode();
    }

    if (key == c.GLFW_KEY_S and action == c.GLFW_PRESS) {
        level_editor.saveLevel("test.lv") catch unreachable;
    }

    if (key == c.GLFW_KEY_L and action == c.GLFW_PRESS) {
        std.debug.print("Pressed L\n", .{});
        level_editor.loadLevel("test.lv") catch unreachable;
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = &arena.allocator;

    var win = try Window.init(640, 640, "junk -- float");
    defer win.close();

    var mgr = try Manager.init(alloc, 500);

    const ctrl = Controller.init(&win);

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

    var debug = try Debug.init(alloc, 500, debug_shader);
    // const telly_src = @embedFile("../assets/telly.png");
    // _ = try Texture.from_memory(telly_src);

    const tileset_src = @embedFile("../assets/wasteland.png");
    const tileset_tex = try Texture.from_memory(tileset_src);
    shader.setInt("tex", 0);

    level_editor = LevelEditor.init(&mgr, win, &debug, tileset_tex);
    _ = c.glfwSetMouseButtonCallback(win.win, mouseCallback);
    _ = c.glfwSetKeyCallback(win.win, keyCallback);

    const frames = [_]Vec2{
        Vec2.init(1, 1),
        Vec2.init(18, 1),
        Vec2.init(35, 1),
        Vec2.init(52, 1),
        Vec2.init(69, 1),
        Vec2.init(86, 1),
    };

    var animation = Animation.init(10, frames[0..]);

    const player_spr = Sprite.with_anim(Vec3.init(200 - 32, 200, 0), 16, 24, animation);
    const tileset_spr = Sprite.init(Vec3.init(0, 0, 0), tileset_tex.width, tileset_tex.height, Vec2.init(0, 0));
    var platform_spr = Sprite.init(Vec3.init(200, 280, 0), 16, 24, Vec2.init(104, 1));

    const player = try mgr.add(player_spr, player_spr.makeBBox());
    _ = try mgr.add(platform_spr, platform_spr.makeBBox());
    platform_spr.pos = platform_spr.pos.sub(Vec3.init(16, 0, 0));
    _ = try mgr.add(platform_spr, platform_spr.makeBBox());
    _ = try mgr.add(tileset_spr, null);

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
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, @sizeOf(Quad) * mgr.quads.items.len), mgr.quads.items.ptr, c.GL_DYNAMIC_DRAW);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(c_long, @sizeOf(u32) * mgr.indices.items.len), mgr.indices.items.ptr, c.GL_DYNAMIC_DRAW);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mgr.indices.items.len), c.GL_UNSIGNED_INT, null);

        // render debug artifacts
        const cursor_pos = level_editor.getCursorPos();
        try debug.drawLine(cursor_pos.add(Vec3.init(0, 0, 0)), cursor_pos.add(Vec3.init(16, 0, 0)));
        try debug.drawLine(cursor_pos.add(Vec3.init(0, 0, 0)), cursor_pos.add(Vec3.init(0, 16, 0)));
        debug.draw();

        // reset bound resources
        c.glBindVertexArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

        win.tick();
        mgr.tick(delta);
        try level_editor.tick();
    }
}
