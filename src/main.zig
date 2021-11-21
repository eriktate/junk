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
const Tex = sprite.Tex;
const Sprite = sprite.Sprite;
const print = std.debug.print;

var level_editor: LevelEditor = undefined;
var debugFlag: bool = true;

const PlayerAnim = enum {
    Idle,
    Running,
    Jumping,
    Falling,
};

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
        level_editor.loadLevel("test.lv") catch unreachable;
    }

    if (key == c.GLFW_KEY_SEMICOLON and action == c.GLFW_PRESS) {
        debugFlag = !debugFlag;
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
    const telly_src = @embedFile("../assets/telly_atlas.png");
    const telly_tex = try Texture.fromMemory(telly_src);

    const tileset_src = @embedFile("../assets/wasteland.png");
    const tileset_tex = try Texture.fromMemory(tileset_src);
    shader.setInt("tex0", 0);
    shader.setInt("tex1", 1);

    level_editor = LevelEditor.init(&mgr, win, &debug, tileset_tex);
    _ = c.glfwSetMouseButtonCallback(win.win, mouseCallback);
    _ = c.glfwSetKeyCallback(win.win, keyCallback);

    var telly_idle = Animation.init(10, 16, 24, telly_tex, undefined);
    var telly_run = Animation.init(7.5, 16, 24, telly_tex, undefined);
    var telly_jump = Animation.init(10, 16, 24, telly_tex, undefined);
    var telly_fall = Animation.init(10, 16, 24, telly_tex, undefined);
    const idle_frames = [_]Vec2{
        telly_idle.fromGridPos(Vec2.init(0, 0)),
        telly_idle.fromGridPos(Vec2.init(1, 0)),
        telly_idle.fromGridPos(Vec2.init(2, 0)),
        telly_idle.fromGridPos(Vec2.init(3, 0)),
        telly_idle.fromGridPos(Vec2.init(4, 0)),
        telly_idle.fromGridPos(Vec2.init(5, 0)),
    };
    const run_frames = [_]Vec2{
        telly_idle.fromGridPos(Vec2.init(0, 1)),
        telly_idle.fromGridPos(Vec2.init(1, 1)),
        telly_idle.fromGridPos(Vec2.init(2, 1)),
        telly_idle.fromGridPos(Vec2.init(3, 1)),
    };
    const jump_frames = [_]Vec2{
        telly_idle.fromGridPos(Vec2.init(0, 2)),
        telly_idle.fromGridPos(Vec2.init(1, 2)),
        telly_idle.fromGridPos(Vec2.init(2, 2)),
        telly_idle.fromGridPos(Vec2.init(3, 2)),
    };
    const fall_frames = [_]Vec2{
        telly_idle.fromGridPos(Vec2.init(0, 3)),
        telly_idle.fromGridPos(Vec2.init(1, 3)),
        telly_idle.fromGridPos(Vec2.init(2, 3)),
        telly_idle.fromGridPos(Vec2.init(3, 3)),
    };
    telly_idle.frames = idle_frames[0..];
    telly_run.frames = run_frames[0..];
    telly_jump.frames = jump_frames[0..];
    telly_fall.frames = fall_frames[0..];

    const player_spr = Sprite.withAnim(Vec3.init(200 - 32, 200, 0), 16, 24, telly_idle);
    const tileset_spr = Sprite.init(Vec3.init(0, 0, 0), tileset_tex.width, tileset_tex.height, Tex.init(tileset_tex.id, Vec2.init(0, 0)));

    const player = try mgr.add(player_spr, player_spr.makeBBox());
    _ = try mgr.add(tileset_spr, null);

    for (mgr.quads.items) |quad| {
        std.debug.print("Quad tex IDs: {d}, {d}, {d}, {d}", .{ quad.tr.tex_id, quad.tl.tex_id, quad.bl.tex_id, quad.br.tex_id });
    }

    var vao: u32 = undefined;
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    var vbo: u32 = undefined;
    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, @sizeOf(Quad) * mgr.quads.items.len), mgr.quads.items.ptr, c.GL_DYNAMIC_DRAW);

    std.debug.print("Size of vertex: {d}\n", .{@sizeOf(Vertex)});
    std.debug.print("Size of offset: {d}\n", .{@sizeOf(Vec3) + @sizeOf(Vec2)});
    std.debug.print("Void pointer offset: {d}\n", .{@intToPtr(*const c_void, 20)});
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glVertexAttribPointer(1, 2, c.GL_UNSIGNED_INT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(*const c_void, @sizeOf(Vec3)));
    c.glVertexAttribIPointer(2, 1, c.GL_UNSIGNED_INT, @sizeOf(Vertex), @intToPtr(*const c_void, @sizeOf(Vec3) + @sizeOf(Vec2)));
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);
    c.glEnableVertexAttribArray(2);

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

    var player_sprite = mgr.getMutSprite(player).?;
    var prev_anim = PlayerAnim.Idle;
    var current_anim = PlayerAnim.Idle;
    while (!win.shouldClose()) {
        current_anim = PlayerAnim.Idle;

        // timings
        now = c.glfwGetTime();
        delta = now - prev_time;
        prev_time = now;

        const grounded = mgr.checkCollisionRelative(player, Vec3.init(0, 1, 0));
        if (!grounded) {
            vspeed += @floatCast(f32, grav * delta);
            if (vspeed < 0) {
                current_anim = PlayerAnim.Jumping;
            } else {
                current_anim = PlayerAnim.Falling;
            }
        }

        var move_vec = Vec3.init(0, vspeed, 0);

        // controll stuff
        if (ctrl.getRight()) {
            player_sprite.setFlipped(false);
            if (grounded) {
                current_anim = PlayerAnim.Running;
            }

            move_vec.x += 0.5;
        }

        if (ctrl.getLeft()) {
            player_sprite.setFlipped(true);
            if (grounded) {
                current_anim = PlayerAnim.Running;
            }

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

        // player animations
        if (prev_anim != current_anim) {
            switch (current_anim) {
                PlayerAnim.Idle => player_sprite.setAnimation(telly_idle),
                PlayerAnim.Running => player_sprite.setAnimation(telly_run),
                PlayerAnim.Jumping => player_sprite.setAnimation(telly_jump),
                PlayerAnim.Falling => player_sprite.setAnimation(telly_fall),
            }
            prev_anim = current_anim;
        }

        shader.use();
        mgr.tick(delta);
        try level_editor.tick();
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
        if (debugFlag) {
            debug.draw();
        }

        // reset bound resources
        c.glBindVertexArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, 0);

        win.tick();
    }
}
