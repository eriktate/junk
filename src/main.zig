const std = @import("std");
const c = @import("c.zig");
const gl = @import("gl.zig");
const lag = @import("lag.zig");
const Window = @import("window.zig");
const Shader = @import("shader.zig");
const Texture = @import("texture.zig");
const sprite = @import("sprite.zig");
const Controller = @import("controller.zig");
const BBox = @import("bbox.zig");
const manager = @import("manager.zig");
const Debug = @import("debug.zig");
const LevelEditor = @import("level_editor.zig").LevelEditor;
const Player = @import("player.zig");
const Camera = @import("camera.zig");

const Quad = gl.Quad;
const Vertex = gl.Vertex;
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const Mat4 = lag.Mat4;
const Animation = sprite.Animation;
const Origin = Texture.Origin;
const Sprite = sprite.Sprite;
const Textures = Texture.Textures;
const Manager = manager.Manager;
const EntityKind = manager.EntityKind;
const print = std.debug.print;

var win: Window = undefined;
var level_editor: LevelEditor = undefined;
var debug: Debug = undefined;

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
        debug.toggle();
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = &arena.allocator;

    win = try Window.init(640, 640, "junk -- float");
    defer win.close();

    var mgr = try Manager.init(alloc, 500);

    const ctrl = Controller.init(&win);

    const vs_src = @embedFile("../shaders/vs.glsl");
    const fs_src = @embedFile("../shaders/fs.glsl");
    const shader = try Shader.init(vs_src, fs_src);

    const debug_vs_src = @embedFile("../shaders/debug_vs.glsl");
    const debug_fs_src = @embedFile("../shaders/debug_fs.glsl");
    const debug_shader = try Shader.init(debug_vs_src, debug_fs_src);

    var camera = Camera.init(&win, Vec3.init(0, 0, 0), lag.Vec2(f32).init(32, 32), 320, 320);
    // set screen resolution uniforms for use in coordinate mapping
    // modifying this affects the "zoom" level
    shader.setUint("width", win.width);
    shader.setUint("height", win.height);
    shader.setMat4("projection", camera.projection());
    debug_shader.setUint("width", win.width);
    debug_shader.setUint("height", win.height);

    debug = try Debug.init(alloc, 500, debug_shader);
    const telly_src = @embedFile("../assets/telly_atlas.png");
    const telly_tex = try Texture.fromMemory(Textures.Telly, telly_src);
    const telly_atlas = telly_tex.makeAtlas(Vec2.init(1, 1), 16, 24, null, null);

    // const wasteland_src = @embedFile("../assets/wasteland.png");
    // const wasteland_tex = try Texture.fromMemory(Textures.Wasteland, wasteland_src);
    const lab_src = @embedFile("../assets/lab.png");
    const lab_tex = try Texture.fromMemory(Textures.Lab, lab_src);
    shader.setInt("tex0", 0);
    shader.setInt("tex1", 1);
    shader.setInt("tex2", 2);

    level_editor = LevelEditor.init(&mgr, win, &debug, lab_tex);
    _ = c.glfwSetMouseButtonCallback(win.win, mouseCallback);
    _ = c.glfwSetKeyCallback(win.win, keyCallback);

    const idle_frames = [_]Vec2{
        telly_atlas.getFrame(Vec2.init(0, 0)).pos,
        telly_atlas.getFrame(Vec2.init(1, 0)).pos,
        telly_atlas.getFrame(Vec2.init(2, 0)).pos,
        telly_atlas.getFrame(Vec2.init(3, 0)).pos,
        telly_atlas.getFrame(Vec2.init(4, 0)).pos,
        telly_atlas.getFrame(Vec2.init(5, 0)).pos,
    };
    const run_frames = [_]Vec2{
        telly_atlas.getFrame(Vec2.init(0, 1)).pos,
        telly_atlas.getFrame(Vec2.init(1, 1)).pos,
        telly_atlas.getFrame(Vec2.init(2, 1)).pos,
        telly_atlas.getFrame(Vec2.init(3, 1)).pos,
    };
    const jump_frames = [_]Vec2{
        telly_atlas.getFrame(Vec2.init(0, 2)).pos,
        telly_atlas.getFrame(Vec2.init(1, 2)).pos,
        telly_atlas.getFrame(Vec2.init(2, 2)).pos,
        telly_atlas.getFrame(Vec2.init(3, 2)).pos,
    };
    const fall_frames = [_]Vec2{
        telly_atlas.getFrame(Vec2.init(0, 3)).pos,
        telly_atlas.getFrame(Vec2.init(1, 3)).pos,
        telly_atlas.getFrame(Vec2.init(2, 3)).pos,
        telly_atlas.getFrame(Vec2.init(3, 3)).pos,
    };

    var telly_idle = Animation.init(10, telly_tex, idle_frames[0..]);
    var telly_run = Animation.init(7.5, telly_tex, run_frames[0..]);
    var telly_jump = Animation.init(10, telly_tex, jump_frames[0..]);
    var telly_fall = Animation.init(10, telly_tex, fall_frames[0..]);

    const player_spr = Sprite.withAnim(Vec3.init(200 - 32, 200, 0), 16, 24, telly_idle);
    // const wasteland_spr = Sprite.init(Vec3.init(0, 0, 0), wasteland_tex.width, wasteland_tex.height, Origin.init(wasteland_tex.idx, Vec2.init(0, 0)));
    const lab_spr = Sprite.init(Vec3.init(0, 0, 0), lab_tex.width, lab_tex.height, Origin.init(lab_tex.idx, Vec2.init(0, 0)));

    const player_id = try mgr.add(EntityKind.Player, player_spr, BBox.init(player_spr.pos, 7, 14).withOffset(Vec3.init(4, 9, 0)));
    _ = try mgr.add(EntityKind.Decor, lab_spr, null);

    var player = Player.init(player_id, &mgr, telly_idle, telly_run, telly_jump, telly_fall);
    var vao: u32 = undefined;
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    var vbo: u32 = undefined;
    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, @sizeOf(Quad) * mgr.quads.items.len), mgr.quads.items.ptr, c.GL_DYNAMIC_DRAW);

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

    while (!win.shouldClose()) {
        // timings
        now = c.glfwGetTime();
        delta = now - prev_time;
        prev_time = now;

        shader.use();
        // player tick _must_ come before manager tick because the
        // player's sprite may be modified
        try player.tick(ctrl, delta);
        mgr.tick(delta);
        try level_editor.tick();
        camera.setTarget(mgr.getSprite(player.id).?.pos);
        shader.setMat4("projection", camera.projection());
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
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, 0);

        win.tick();
    }
}
