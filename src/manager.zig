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

pub const Entity = struct {
    id: usize,
    sprite_idx: ?usize,
    box_idx: ?usize,
    quad_idx: ?usize,

    pub fn init(id: usize, sprite_idx: ?usize, box_idx: ?usize, quad_idx: ?usize) Entity {
        return Entity{
            .id = id,
            .sprite_idx = sprite_idx,
            .box_idx = box_idx,
            .quad_idx = quad_idx,
        };
    }
};

// NOTE: quads _can't_ be optional because it messes with their in-memory representation
pub const Manager = struct {
    alloc: *Allocator,

    entities: ArrayList(?Entity),
    sprites: ArrayList(?Sprite),
    boxes: ArrayList(?BBox),
    quads: ArrayList(Quad),
    indices: ArrayList(u32),
    // TODO (etate): Maybe add an array of entities in the future?

    pub fn init(alloc: *Allocator, cap: u64) !Manager {
        var entities = ArrayList(?Entity).init(alloc);
        var sprites = ArrayList(?Sprite).init(alloc);
        var quads = ArrayList(Quad).init(alloc);
        var boxes = ArrayList(?BBox).init(alloc);
        var indices = ArrayList(u32).init(alloc);

        // ensuring capacity should allocate all of our memory of front and
        // then never again outside of something crazy happening
        try entities.ensureTotalCapacity(cap);
        try sprites.ensureTotalCapacity(cap);
        try quads.ensureTotalCapacity(cap);
        try boxes.ensureTotalCapacity(cap);
        try indices.ensureTotalCapacity(cap * 6);

        return Manager{
            .alloc = alloc,
            .entities = entities,
            .sprites = sprites,
            .quads = quads,
            .boxes = boxes,
            .indices = indices,
        };
    }

    pub fn add(self: *Manager, sprite: Sprite) !usize {
        var entity = Entity.init(self.entities.items.len, self.sprites.items.len, self.boxes.items.len, self.quads.items.len);
        var spr = sprite;

        // look for empty entity slots
        for (self.entities.items) |ent, idx| {
            if (ent == null) {
                entity.id = idx;
            }
        }
        spr.id = entity.id;

        // look for empty sprite slots
        for (self.sprites.items) |s, idx| {
            if (s == null) {
                entity.sprite_idx = idx;
                self.sprites.items[idx] = spr;
            }
        }

        // look for empty bounding box slots
        for (self.boxes.items) |box, idx| {
            if (box == null) {
                var new_box = spr.makeBBox();
                new_box.id = entity.id;
                entity.box_idx = idx;
                self.boxes.items[idx] = box;
            }
        }

        // look for empty quad slots
        for (self.quads.items) |quad, idx| {
            if (quad.eq(Quad.zero())) {
                entity.box_idx = idx;
                self.quads.items[idx] = spr.toQuad();
            }
        }

        // no empty slots found, so append to the end
        if (entity.id == self.entities.items.len) {
            try self.entities.append(entity);
        }

        if (entity.sprite_idx == self.sprites.items.len) {
            try self.sprites.append(spr);
        }

        if (entity.box_idx == self.boxes.items.len) {
            try self.boxes.append(spr.makeBBox());
        }

        if (entity.quad_idx == self.quads.items.len) {
            try self.quads.append(spr.toQuad());

            const id_u32 = @intCast(u32, entity.quad_idx.?);
            // TODO (etate): this doesn't account for shapes other than quads (which might be fine?)
            // add new indices for the new quad
            try self.indices.append(id_u32 * 4);
            try self.indices.append(id_u32 * 4 + 1);
            try self.indices.append(id_u32 * 4 + 2);
            try self.indices.append(id_u32 * 4 + 2);
            try self.indices.append(id_u32 * 4 + 3);
            try self.indices.append(id_u32 * 4);
        }

        return entity.id;
    }

    // TODO (etate): Removals are going to be hard, because Quads need to be actually contiguous.
    pub fn remove(self: Manager, id: usize) void {
        // null/zero slots will get re-used by the add function
        if (self.entities.items[id]) |entity| {
            if (entity.sprite_idx) |idx| {
                self.sprites.items[idx] = null;
            }

            if (entity.box_idx) |idx| {
                self.boxes.items[idx] = null;
            }

            if (entity.quad_idx) |idx| {
                self.quads.items[idx] = Quad.zero();
            }

            self.entities.items[id] = null;
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
        const target = self.getBox(id) orelse return false;
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
        if (id < self.entities.items.len) {
            if (self.entities.items[id]) |entity| {
                if (entity.box_idx) |idx| {
                    return &self.boxes.items[idx].?;
                }
            }
        }

        return null;
    }

    pub fn getBox(self: Manager, id: usize) ?BBox {
        if (id < self.entities.items.len) {
            if (self.entities.items[id]) |entity| {
                if (entity.box_idx) |idx| {
                    return self.boxes.items[idx];
                }
            }
        }

        return null;
    }

    pub fn getMutSprite(self: Manager, id: usize) ?*Sprite {
        if (id < self.entities.items.len) {
            if (self.entities.items[id]) |entity| {
                if (entity.sprite_idx) |idx| {
                    return &self.sprites.items[idx].?;
                }
            }
        }

        return null;
    }

    pub fn getSprite(self: Manager, id: usize) ?Sprite {
        if (id < self.entities.items.len) {
            if (self.entities.items[id]) |entity| {
                if (entity.sprite_idx) |idx| {
                    return self.sprites.items[idx];
                }
            }
        }

        return null;
    }

    pub fn move(self: Manager, id: usize, move_vec: Vec3) ManagerError!Vec3 {
        if (id > self.entities.items.len) {
            return ManagerError.DoesNotExist;
        }

        var res: Vec3 = undefined;
        if (self.getMutSprite(id)) |spr| {
            spr.pos = spr.pos.add(move_vec);
            res = spr.pos;
        }

        if (self.getMutBox(id)) |box| {
            box.pos = box.pos.add(move_vec);
            res = box.pos;
        }

        return res;
    }

    // mostly for the level editor
    pub fn getAtPos(self: Manager, pos: Vec3) ?usize {
        for (self.sprites.items) |opt_spr| {
            if (opt_spr) |spr| {
                if (spr.pos.eq(pos)) {
                    return spr.id;
                }
            }
        }

        return null;
    }
};
