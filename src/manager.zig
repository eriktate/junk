const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const lag = @import("lag.zig");
const Sprite = @import("sprite.zig").Sprite;
const Quad = @import("gl.zig").Quad;
const BBox = @import("bbox.zig");
const Debug = @import("debug.zig");
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

    pub fn add(self: *Manager, opt_sprite: ?Sprite, opt_bbox: ?BBox) !usize {
        var entity = &Entity.init(self.entities.items.len, null, null, null);

        // look for empty entity slots
        for (self.entities.items) |ent, idx| {
            if (ent == null) {
                entity.id = idx;
                self.entities.items[idx] = entity.*;
                entity = &self.entities.items[idx].?;
                break;
            }
        }

        // look for empty sprite slots
        if (opt_sprite) |sprite| {
            var spr = sprite;
            spr.id = entity.id;
            for (self.sprites.items) |existing, idx| {
                if (existing == null) {
                    entity.sprite_idx = idx;
                    self.sprites.items[idx] = spr;
                    break;
                }
            }

            // look for empty quad slots
            for (self.quads.items) |quad, idx| {
                if (quad.eq(Quad.zero())) {
                    entity.quad_idx = idx;
                    self.quads.items[idx] = spr.toQuad();
                    break;
                }
            }
        }

        // look for empty bounding box slots
        if (opt_bbox) |bbox| {
            var box = bbox;
            box.id = entity.id;
            for (self.boxes.items) |existing, idx| {
                if (existing == null) {
                    box.id = entity.id;
                    entity.box_idx = idx;
                    self.boxes.items[idx] = box;
                    break;
                }
            }
        }

        // no empty slots found, so append to the end
        if (entity.id == self.entities.items.len) {
            try self.entities.append(entity.*);
            entity = &self.entities.items[entity.id].?;
        }

        if (opt_sprite) |sprite| {
            var spr = sprite;
            if (entity.sprite_idx == null) {
                entity.sprite_idx = self.sprites.items.len;
                spr.id = entity.id;
                try self.sprites.append(spr);
            }

            if (entity.quad_idx == null) {
                entity.quad_idx = self.quads.items.len;
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
        }

        if (opt_bbox) |bbox| {
            var box = bbox;
            box.id = entity.id;
            if (entity.box_idx == null) {
                entity.box_idx = self.boxes.items.len;
                box.id = entity.id;
                try self.boxes.append(box);
            }
        }

        return entity.id;
    }

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

    // clears everything from the entity manager
    pub fn clear(self: Manager) void {
        for (self.entities.items) |_, idx| {
            if (idx == 0) {
                // skip player
                continue;
            }
            self.entities.items[idx] = null;
        }

        for (self.sprites.items) |_, idx| {
            if (idx == 0) {
                // skip player
                continue;
            }
            self.sprites.items[idx] = null;
        }

        for (self.boxes.items) |_, idx| {
            if (idx == 0) {
                // skip player
                continue;
            }
            self.boxes.items[idx] = null;
        }

        for (self.quads.items) |_, idx| {
            if (idx == 0) {
                // skip player
                continue;
            }
            self.quads.items[idx] = Quad.zero();
        }
    }

    pub fn checkCollision(self: Manager, id: usize, pos: Vec3) ?usize {
        var target = self.boxes.items[id].?;
        target.pos = pos;

        for (self.boxes.items) |opt_box| {
            if (opt_box) |box| {
                if (box.id == id) {
                    continue;
                }

                if (target.overlaps(box)) {
                    return box.id;
                }
            }
        }

        return null;
    }

    pub fn checkCollisionRelative(self: Manager, id: usize, pos: Vec3) ?usize {
        const target = self.getBox(id) orelse return null;
        return self.checkCollision(id, target.pos.add(pos));
    }

    pub fn checkPos(self: Manager, pos: Vec3) ?usize {
        for (self.boxes.items) |opt_box| {
            if (opt_box) |box| {
                if (box.contains(pos)) {
                    return box.id;
                }
            }
        }

        return null;
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

    pub fn drawBoxes(self: Manager, debug: *Debug) !void {
        for (self.boxes.items) |opt_box| {
            if (opt_box) |box| {
                // top
                try debug.drawLine(box.pos, box.pos.add(Vec3.init(box.width, 0, 0)));
                // left
                try debug.drawLine(box.pos, box.pos.add(Vec3.init(0, box.height, 0)));
                // bottom
                try debug.drawLine(box.pos.add(Vec3.init(0, box.height, 0)), box.pos.add(Vec3.init(box.width, box.height, 0)));
                // right
                try debug.drawLine(box.pos.add(Vec3.init(box.width, 0, 0)), box.pos.add(Vec3.init(box.width, box.height, 0)));
            }
        }
    }
};
