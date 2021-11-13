const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const lag = @import("lag.zig");
const Sprite = @import("sprite.zig").Sprite;
const Quad = @import("gl.zig").Quad;
const BBox = @import("bbox.zig").BBox;
const Vec3 = lag.Vec3(f32);
const Vec2 = lag.Vec2(u32);

const ManagerError = error{
    DoesNotExist,
};

// NOTE: quads _can't_ be optional because it messes with their in-memory representation
pub const Manager = struct {
    alloc: *Allocator,

    sprites: ArrayList(?Sprite),
    boxes: ArrayList(?BBox),
    quads: ArrayList(Quad),
    indices: ArrayList(u32),
    // TODO (etate): Maybe add an array of entities in the future?

    pub fn init(alloc: *Allocator, cap: u64) !Manager {
        var sprites = ArrayList(?Sprite).init(alloc);
        var quads = ArrayList(Quad).init(alloc);
        var boxes = ArrayList(?BBox).init(alloc);
        var indices = ArrayList(u32).init(alloc);

        // ensuring capacity should allocate all of our memory of front and
        // then never again outside of something crazy happening
        try sprites.ensureTotalCapacity(cap);
        try quads.ensureTotalCapacity(cap);
        try boxes.ensureTotalCapacity(cap);
        try indices.ensureTotalCapacity(cap * 6);

        return Manager{
            .alloc = alloc,
            .sprites = sprites,
            .quads = quads,
            .boxes = boxes,
            .indices = indices,
        };
    }

    pub fn add(self: *Manager, sprite: Sprite) !usize {
        var spr = sprite;
        // len of one array is total number of entities
        const id = self.sprites.items.len;
        spr.id = id;

        // look for empty slots to use before increasing array size
        // we iterate over boxes just because it's the smallest element size
        for (self.boxes.items) |box, idx| {
            if (box == null) {
                spr.id = idx;
                self.sprites.items[idx] = spr;
                self.quads.items[idx] = spr.toQuad();
                self.boxes.items[idx] = spr.makeBBox();
                return idx;
            }
        }

        // no empty slots found, so append to the end
        try self.sprites.append(spr);
        try self.quads.append(spr.toQuad());
        try self.boxes.append(spr.makeBBox());

        const id_u32 = @intCast(u32, id);
        // add new indices for the new quad
        try self.indices.append(id_u32 * 4);
        try self.indices.append(id_u32 * 4 + 1);
        try self.indices.append(id_u32 * 4 + 2);
        try self.indices.append(id_u32 * 4 + 2);
        try self.indices.append(id_u32 * 4 + 3);
        try self.indices.append(id_u32 * 4);

        return id;
    }

    // TODO (etate): Removals are going to be hard, because Quads need to be actually contiguous.
    pub fn remove(self: Manager, id: usize) void {
        // null slots will get re-used by the add function
        self.sprites.items[id] = null;
        self.quads.items[id] = null;
        self.boxes.items[id] = null;

        // need to wipe 6 indices per quad
        var count = 0;
        while (count < 6) {
            self.indices.items[id * 6 + count] = null;
            count += 1;
        }
    }

    pub fn checkCollision(self: Manager, id: usize, pos: Vec3) bool {
        var target = self.boxes.items[id].?;
        target.pos = pos;

        for (self.boxes.items) |opt_box| {
            if (opt_box) |box| {
                if (box.id == id) {
                    continue;
                }

                if (target.overlaps(box)) {
                    return true;
                }
            }
        }

        return false;
    }

    pub fn checkCollisionRelative(self: Manager, id: usize, pos: Vec3) bool {
        const target = self.boxes.items[id].?;
        return self.checkCollision(id, target.pos.add(pos));
    }

    pub fn tick(self: Manager, delta: f64) void {
        for (self.sprites.items) |*opt_spr, idx| {
            if (opt_spr.*) |*spr| {
                spr.tick(delta);
                self.quads.items[idx] = spr.toQuad();
            }
        }
    }

    pub fn getMutBox(self: Manager, id: usize) ?*BBox {
        if (id < self.boxes.items.len) {
            if (self.boxes.items[id]) |*box| {
                return box;
            }
        }

        return null;
    }

    pub fn getBox(self: Manager, id: usize) ?BBox {
        if (id < self.boxes.items.len) {
            return self.boxes.items[id];
        }

        return null;
    }

    pub fn getMutSprite(self: Manager, id: usize) ?*Sprite {
        if (id < self.sprites.items.len) {
            if (self.sprites.items[id]) |*sprite| {
                return sprite;
            }
        }

        return null;
    }

    pub fn getSprite(self: Manager, id: usize) ?Sprite {
        if (id < self.sprites.items.len) {
            return self.sprites.items[id];
        }

        return null;
    }

    pub fn move(self: Manager, id: usize, move_vec: Vec3) ManagerError!Vec3 {
        if (id > self.sprites.items.len) {
            return ManagerError.DoesNotExist;
        }

        var spr = self.getMutSprite(id).?;
        var box = self.getMutBox(id).?;

        spr.pos = spr.pos.add(move_vec);
        box.pos = spr.pos;
        return spr.pos;
    }
};
