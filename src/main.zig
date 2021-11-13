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

const Quad = gl.Quad;
const Vertex = gl.Vertex;
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);
const Animation = sprite.Animation;
const Sprite = sprite.Sprite;
const print = std.debug.print;

fn doesCollide(target: BBox, others: []BBox) bool {
    for (others) |box| {
        if (box.id == target.id) {
            continue;
        }

        if (target.overlaps(box)) {
            return true;
        }
    }

    return false;
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = &arena.allocator;

    var win = try Window.init(640, 640, "kaizo -- float");
    defer win.close();

    const ctrl = Controller.init(&win);
    var mgr = try Manager.init(alloc, 500);

    const vs_src = @embedFile("../shaders/vs.glsl");
    const fs_src = @embedFile("../shaders/fs.glsl");
    const shader = try Shader.init(vs_src, fs_src);
    shader.use();

    // set screen resolution uniforms for use in coordinate mapping
    // modifying this affects the "zoom" level
    shader.setUint("width", win.width / 2);
    shader.setUint("height", win.height / 2);

    const telly_src: []const u8 = @embedFile("../assets/telly.png");
    _ = try Texture.from_memory(telly_src);

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

    var quads: [3]Quad = undefined;
    quads[0] = mgr.quads.items[0];
    quads[1] = mgr.quads.items[1];
    quads[2] = mgr.quads.items[2];

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

        gl.clear();
        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @intCast(c_long, @sizeOf(Quad) * mgr.quads.items.len), mgr.quads.items.ptr);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mgr.indices.items.len), c.GL_UNSIGNED_INT, null);
        c.glBindVertexArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

        win.tick();
        mgr.tick(delta);
    }
}
