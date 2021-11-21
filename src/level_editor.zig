const std = @import("std");
const lag = @import("lag.zig");
const sprite = @import("sprite.zig");
const Manager = @import("manager.zig").Manager;
const Window = @import("window.zig");
const Texture = @import("texture.zig");
const Debug = @import("debug.zig");
const BBox = @import("bbox.zig");
const fixedBufferStream = std.io.fixedBufferStream;
const Allocator = std.mem.Allocator;
const Sprite = sprite.Sprite;
const Tex = sprite.Tex;
const ShowTag = sprite.ShowTag;
const Vec2 = lag.Vec2(u32);
const Vec3 = lag.Vec3(f32);

const Mode = enum {
    Tile,
    BBox,
};

pub const LevelEditor = struct {
    active_tileset: Texture,
    selected_tile: Vec2,
    mode: Mode,
    lmb_pressed: bool,
    rmb_pressed: bool,
    win: Window,
    active_bbox: ?*BBox,
    manager: *Manager,
    debug: *Debug,

    pub fn init(manager: *Manager, win: Window, debug: *Debug, active_tileset: Texture) LevelEditor {
        return LevelEditor{
            .active_tileset = active_tileset,
            .selected_tile = Vec2.zero(),
            .lmb_pressed = false,
            .rmb_pressed = false,
            .manager = manager,
            .mode = Mode.BBox,
            .active_bbox = null,
            .win = win,
            .debug = debug,
        };
    }

    pub fn useTileset(self: *LevelEditor, id: u32) void {
        self.active_tileset = id;
    }

    pub fn selectTile(self: *LevelEditor, pos: Vec3) void {
        self.selected_tile = Vec2.init(@floatToInt(u32, pos.x), @floatToInt(u32, pos.y));
    }

    fn getSelectedTileTex(self: LevelEditor) Tex {
        return Tex.init(
            self.active_tileset.id,
            self.selected_tile,
        );
    }

    pub fn addTile(self: LevelEditor, pos: Vec3) !void {
        const tile = Sprite.init(pos, 16, 16, self.getSelectedTileTex());
        if (self.manager.getAtPos(pos)) |id| {
            const spr = self.manager.getSprite(id).?;
            switch (spr.show) {
                ShowTag.tex => |tex| {
                    if (!tex.eq(self.getSelectedTileTex())) {
                        self.manager.remove(id);
                        _ = try self.manager.add(tile, null);
                    }
                    return;
                },
                ShowTag.anim => return,
            }
        }

        _ = try self.manager.add(tile, null);
    }

    pub fn removeTile(self: LevelEditor, pos: Vec3) void {
        if (self.manager.getAtPos(pos)) |id| {
            self.manager.remove(id);
        }
    }

    pub fn getCursorPos(self: LevelEditor) Vec3 {
        // get cursor pos
        var cursor_pos = self.win.getMousePos();
        cursor_pos.x = @divTrunc(cursor_pos.x, 16);
        cursor_pos.y = @divTrunc(cursor_pos.y, 16);
        cursor_pos = cursor_pos.scale(16);

        return cursor_pos;
    }

    pub fn handleLMB(self: *LevelEditor, pressed: bool) void {
        self.lmb_pressed = pressed;
        const cursor_pos = self.getCursorPos();

        if (self.lmb_pressed and self.mode == Mode.Tile) {
            if (cursor_pos.x < @intToFloat(f32, self.active_tileset.width) and cursor_pos.y < @intToFloat(f32, self.active_tileset.height)) {
                self.selectTile(cursor_pos);
                return;
            }

            self.addTile(cursor_pos) catch unreachable;
        }

        if (self.mode == Mode.BBox) {
            if (self.lmb_pressed) {
                const box = BBox.init(0, cursor_pos, 16, 16);
                const id = self.manager.add(null, box) catch unreachable;
                self.active_bbox = self.manager.getMutBox(id).?;
                return;
            }

            // make sure we don't have negative width/height
            if (self.active_bbox) |bbox| {
                if (bbox.width == 0 or bbox.height == 0) {
                    self.manager.remove(bbox.id);
                    self.active_bbox = null;
                }

                var adjustment = Vec3.zero();
                if (bbox.width < 0) {
                    adjustment.x = bbox.width;
                    bbox.width *= -1;
                }

                if (bbox.height < 0) {
                    adjustment.y = bbox.height;
                    bbox.height *= -1;
                }

                bbox.pos = bbox.pos.add(adjustment);
            }
            self.active_bbox = null;
        }
    }

    pub fn handleRMB(self: *LevelEditor, pressed: bool) void {
        self.rmb_pressed = pressed;
        self.tick() catch unreachable;
    }

    pub fn toggleMode(self: *LevelEditor) void {
        if (self.mode == Mode.Tile) {
            self.mode = Mode.BBox;
            std.debug.print("{any}\n", .{self.mode});
            return;
        }

        self.mode = Mode.Tile;
        std.debug.print("{any}\n", .{self.mode});
    }

    pub fn tick(self: *LevelEditor) !void {
        const mouse_pos = self.win.getMousePos();
        const cursor_pos = self.getCursorPos();
        if (self.lmb_pressed) {
            if (self.mode == Mode.Tile) {
                if (cursor_pos.x > @intToFloat(f32, self.active_tileset.width) or cursor_pos.y > @intToFloat(f32, self.active_tileset.height)) {
                    try self.addTile(cursor_pos);
                }
            }

            if (self.mode == Mode.BBox) {
                if (self.active_bbox) |bbox| {
                    const new_dimensions = cursor_pos.sub(bbox.pos);
                    bbox.width = new_dimensions.x;
                    bbox.height = new_dimensions.y;
                }
            }
        }

        if (self.rmb_pressed) {
            if (self.mode == Mode.Tile) {
                self.removeTile(cursor_pos);
            }

            if (self.mode == Mode.BBox) {
                const opt_id = self.manager.checkPos(mouse_pos);
                if (opt_id) |id| {
                    self.manager.remove(id);
                }
            }
        }

        try self.manager.drawBoxes(self.debug);
    }

    // TODO (etate): maybe rip all of this out and use the
    // de/serialization in std-lib-orphanage
    pub fn serialize(self: LevelEditor, fb: anytype) !void {
        var tile_len: u32 = 0;
        var box_len: u32 = 0;
        var writer = fb.writer();

        // reserve space for tile_len and box_len
        try writer.writeIntLittle(u32, 0);
        try writer.writeIntLittle(u32, 0);

        for (self.manager.sprites.items) |opt_spr| {
            if (opt_spr) |spr| {
                const tex = spr.getTex();
                try writer.writeIntLittle(u32, @floatToInt(u32, spr.pos.x));
                try writer.writeIntLittle(u32, @floatToInt(u32, spr.pos.y));
                try writer.writeIntLittle(u32, self.active_tileset.id);
                try writer.writeIntLittle(u32, tex.x);
                try writer.writeIntLittle(u32, tex.y);

                tile_len += 1;
            }
        }

        for (self.manager.boxes.items) |opt_box| {
            if (opt_box) |bbox| {
                try writer.writeIntLittle(u32, @floatToInt(u32, bbox.pos.x));
                try writer.writeIntLittle(u32, @floatToInt(u32, bbox.pos.y));
                try writer.writeIntLittle(u32, @floatToInt(u32, bbox.width));
                try writer.writeIntLittle(u32, @floatToInt(u32, bbox.height));

                box_len += 1;
            }
        }

        const pos = fb.pos;
        fb.pos = 0;
        try writer.writeIntLittle(u32, tile_len);
        try writer.writeIntLittle(u32, box_len);
        fb.pos = pos;
    }

    pub fn deserialize(self: LevelEditor, reader: anytype) !void {
        self.manager.clear();
        const tile_len = try reader.readIntLittle(u32);
        const box_len = try reader.readIntLittle(u32);

        var idx: usize = 0;
        while (idx < tile_len) {
            var pos = Vec3.zero();
            var tex_coord = Vec2.zero();
            pos.x = @intToFloat(f32, try reader.readIntLittle(u32));
            pos.y = @intToFloat(f32, try reader.readIntLittle(u32));

            const tex_id = try reader.readIntLittle(u32);

            tex_coord.x = try reader.readIntLittle(u32);
            tex_coord.y = try reader.readIntLittle(u32);

            var tile = Sprite.init(pos, 16, 16, Tex.init(tex_id, tex_coord));
            _ = self.manager.add(tile, null) catch unreachable;

            idx += 1;
        }

        idx = 0;
        while (idx < box_len) {
            var pos = Vec3.zero();
            var width: u32 = 0;
            var height: u32 = 0;
            pos.x = @intToFloat(f32, try reader.readIntLittle(u32));
            pos.y = @intToFloat(f32, try reader.readIntLittle(u32));
            width = try reader.readIntLittle(u32);
            height = try reader.readIntLittle(u32);
            const box = BBox.init(0, pos, width, height);
            _ = self.manager.add(null, box) catch unreachable;
            idx += 1;
        }
    }

    pub fn saveLevel(self: LevelEditor, fname: []const u8) !void {
        var file = try std.fs.cwd().createFile(
            fname,
            .{},
        );
        defer file.close();

        var buffer: [2 * 1024 * 1024]u8 = undefined;
        var fb = fixedBufferStream(buffer[0..]);

        try self.serialize(&fb);
        try file.writeAll(fb.getWritten());
        std.debug.print("Level saved!\n", .{});
    }

    pub fn loadLevel(self: LevelEditor, fname: []const u8) !void {
        var file = try std.fs.cwd().openFile(
            fname,
            .{ .read = true },
        );
        defer file.close();

        try self.deserialize(file.reader());
        std.debug.print("Level loaded!\n", .{});
    }
};
