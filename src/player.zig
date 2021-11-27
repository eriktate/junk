const Controller = @import("controller.zig");
const Animation = @import("sprite.zig").Animation;
const Manager = @import("manager.zig").Manager;
const Vec3 = @import("lag.zig").Vec3(f32);
const globals = @import("globals.zig");

const jumpForce = 1.5;
const State = enum {
    Idle,
    Running,
    Jumping,
    Falling,
    None,
};

const Player = @This();
id: usize,
state: State,
mgr: *Manager,
anims: [@enumToInt(State.None)]Animation,
vspeed: f32,

pub fn init(id: usize, mgr: *Manager, idle: Animation, running: Animation, jumping: Animation, falling: Animation) Player {
    var player = Player{
        .id = id,
        .state = State.Idle,
        .mgr = mgr,
        .vspeed = 0,
        .anims = undefined,
    };

    // init animation lookup
    player.anims[@enumToInt(State.Idle)] = idle;
    player.anims[@enumToInt(State.Running)] = running;
    player.anims[@enumToInt(State.Jumping)] = jumping;
    player.anims[@enumToInt(State.Falling)] = falling;

    return player;
}

pub fn tick(self: *Player, ctrl: Controller, delta: f64) !void {
    const prev_state = self.state;
    self.state = State.Idle;

    const grounded = self.mgr.checkCollisionRelative(self.id, Vec3.init(0, 1, 0)) != null;
    if (!grounded) {
        self.vspeed += @floatCast(f32, globals.grav * delta);
        if (self.vspeed < 0) {
            self.state = State.Jumping;
        } else {
            self.state = State.Falling;
        }
    }

    if (ctrl.getJump() and grounded) {
        self.vspeed = -jumpForce;
        self.state = State.Jumping;
    }

    // the player entity _must_ have a sprite, so we can unwrap here
    var spr = self.mgr.getMutSprite(self.id).?;
    var move_vec = Vec3.init(0, self.vspeed, 0);

    if (ctrl.getRight()) {
        spr.setFlipped(false);
        if (grounded) {
            self.state = State.Running;
        }
        move_vec.x += 0.7;
    }

    if (ctrl.getLeft()) {
        spr.setFlipped(true);
        if (grounded) {
            self.state = State.Running;
        }

        move_vec.x -= 0.7;
    }

    if (self.mgr.checkCollisionRelative(self.id, Vec3.init(move_vec.x, 0, 0)) != null) {
        move_vec.x = 0;
    }

    if (self.mgr.checkCollisionRelative(self.id, Vec3.init(0, move_vec.y, 0)) != null) {
        move_vec.y = 0;
        self.vspeed = 0;
    }

    _ = try self.mgr.move(self.id, move_vec);

    if (prev_state != self.state) {
        spr.setAnimation(self.anims[@enumToInt(self.state)]);
    }
}
