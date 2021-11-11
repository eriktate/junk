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
    var win = try Window.init(640, 640, "kaizo -- float");
    defer win.close();

    const ctrl = Controller.init(&win);
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
    const telly = Sprite.init(0, Vec3.init(200, 280, 0), 16, 24, Vec2.init(1, 1));
    var player = Sprite.with_anim(1, Vec3.init(200 - 32, 200, 0), 16, 24, animation);
    var platform = Sprite.init(2, Vec3.init(200 - 32, 264, 0), 16, 24, Vec2.init(104, 1));

    var bounding_boxes = [_]BBox{
        telly.makeBBox(),
        player.makeBBox(),
        platform.makeBBox(),
    };

    var quads = [_]Quad{
        telly.toQuad(),
        player.toQuad(),
        platform.toQuad(),
    };

    var indices: [quads.len * 6]u32 = undefined;
    gl.makeIndices(quads[0..], &indices);

    var vao: u32 = undefined;
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    var vbo: u32 = undefined;
    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(Quad) * quads.len, &quads, c.GL_DYNAMIC_DRAW);

    const tex_offset = @sizeOf(Vec3);
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glVertexAttribPointer(1, 2, c.GL_UNSIGNED_INT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(*const c_void, tex_offset));
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);

    var ebo: u32 = undefined;
    c.glGenBuffers(1, &ebo);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * indices.len, &indices, c.GL_DYNAMIC_DRAW);

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

        var player_box = player.makeBBox();
        player_box.pos = player_box.pos.add(Vec3.init(0, 1, 0));
        const grounded = doesCollide(player_box, bounding_boxes[0..]);
        if (!grounded) {
            vspeed += @floatCast(f32, grav * delta);
        }

        // var new_pos = player.pos;
        var new_pos = player.pos.add(Vec3.init(0, vspeed, 0));

        // controll stuff
        if (ctrl.getRight()) {
            new_pos = new_pos.add(Vec3.init(0.5, 0, 0));
        }

        if (ctrl.getLeft()) {
            new_pos = new_pos.add(Vec3.init(-0.5, 0, 0));
        }

        if (ctrl.getJump()) {
            if (grounded) {
                vspeed = -1;
            }
        }

        // check x
        player_box.pos = Vec3.init(new_pos.x, player.pos.y, 0);
        if (doesCollide(player_box, bounding_boxes[0..])) {
            print("X collision!\n", .{});
            new_pos.x = player.pos.x;
        }

        // check y
        player_box.pos = Vec3.init(player.pos.x, new_pos.y, 0);
        if (doesCollide(player_box, bounding_boxes[0..])) {
            print("Y collision!\n", .{});
            new_pos.y = player.pos.y;
            vspeed = 0;
        }

        player.pos = new_pos;
        bounding_boxes[player.id].pos = new_pos;

        gl.clear();
        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @sizeOf(Quad) * quads.len, &quads);
        c.glDrawElements(c.GL_TRIANGLES, indices.len, c.GL_UNSIGNED_INT, null);
        c.glBindVertexArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

        win.tick();
        player.tick(delta);
        quads[1] = player.toQuad();
    }
}
