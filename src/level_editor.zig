const std = @import("std");
const lag = @import("lag.zig");
const sprite = @import("sprite.zig");
const Manager = @import("manager.zig").Manager;
const Window = @import("window.zig").Window;
const Texture = @import("texture.zig").Texture;
const Debug = @import("debug.zig").Debug;
const BBox = @import("bbox.zig").BBox;
const Allocator = std.mem.Allocator;
const Sprite = sprite.Sprite;
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
        std.debug.print("Selecting tile: {d}, {d}\n", .{ pos.x, pos.y });
        self.selected_tile = Vec2.init(@floatToInt(u32, pos.x), @floatToInt(u32, pos.y));
    }

    pub fn addTile(self: LevelEditor, pos: Vec3) !void {
        const tile = Sprite.init(pos, 16, 16, self.selected_tile);
        if (self.manager.getAtPos(pos)) |id| {
            const spr = self.manager.getSprite(id).?;
            switch (spr.show) {
                ShowTag.tex => |tex| {
                    if (!tex.eq(self.selected_tile)) {
                        std.debug.print("Overwriting tile {d}, {d} to {d}, {d}\n", .{ self.selected_tile.x, self.selected_tile.y, pos.x, pos.y });
                        self.manager.remove(id);
                        _ = try self.manager.add(tile, null);
                    }
                    return;
                },
                ShowTag.anim => return,
            }
        }

        const id = try self.manager.add(tile, null);
        std.debug.print("Adding tile {d}, {d} to {d}, {d} with id {d}\n", .{ self.selected_tile.x, self.selected_tile.y, pos.x, pos.y, id });
    }

    pub fn removeTile(self: LevelEditor, pos: Vec3) void {
        if (self.manager.getAtPos(pos)) |id| {
            std.debug.print("Removing entity: {d}\n", .{id});
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
            std.debug.print("Mode: {any}\n", .{self.mode});
            return;
        }

        self.mode = Mode.Tile;
        std.debug.print("Mode: {any}\n", .{self.mode});
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

    pub fn serialize(self: LevelEditor) void {
        const tile_size = 5 * @sizeOf(u32);
        const box_size = 4 * @sizeOf(u32);

        var tile_len: u32 = 0;
        var box_len: u32 = 0;
        var buffer: [1024 * 1024 * 2]u8 = undefined;
        var idx: usize = 2 * @sizeOf(u32);

        for (self.manager.sprites.items) |opt_spr| {
            if (opt_spr) |spr| {
                // const mask: u32 = 255;
                // const x = @floatToInt(u32, spr.pos.x);
                // var x_bytes: [4]u8 = undefined;
                // x_bytes[3] = x & mask;
                // x_bytes[2] = @shrExact(x, 8) & mask;
                // x_bytes[1] = @shrExact(x, 16) & mask;
                // x_bytes[0] = @shrExact(x, 24) & mask;
                var tile: [6]u32 = undefined;
                const tex = spr.getTex();
                tile[0] = @floatToInt(u32, spr.pos.x);
                tile[1] = @floatToInt(u32, spr.pos.y);
                tile[2] = 0;
                tile[3] = tex.x;
                tile[4] = tex.y;

                @memcpy(@ptrCast([*]u8, &buffer[idx]), @ptrCast([*]const u8, &tile), tile_size);
                idx += tile_size;
                tile_len += 1;
            }
        }

        for (self.manager.boxes.items) |opt_box| {
            if (opt_box) |bbox| {
                var box: [4]u32 = undefined;
                box[0] = @floatToInt(u32, bbox.pos.x);
                box[1] = @floatToInt(u32, bbox.pos.y);
                box[2] = @floatToInt(u32, bbox.width);
                box[3] = @floatToInt(u32, bbox.height);

                @memcpy(@ptrCast([*]u8, &buffer[idx]), @ptrCast([*]const u8, &box), box_size);
                idx += 4;
                box_len += 1;
            }
        }

        std.debug.print("ACTUAL TILE LEN: {d}\n", .{tile_len});
        std.debug.print("ACTUAL BOX LEN: {d}\n", .{box_len});
        std.mem.copy(u8, buffer[0..4], std.mem.asBytes(&tile_len));
        std.mem.copy(u8, buffer[4..8], std.mem.asBytes(&box_len));

        var count: usize = 0;
        while (count < idx) {
            std.debug.print("{x}", .{buffer[count]});
            count += 1;
        }
        std.debug.print("\n", .{});
        deserialize(buffer[0..]);
    }

    fn ReadResult(comptime T: type) type {
        return struct {
            val: T,
            input: []u8,
        };
    }

    fn read(comptime T: type, input: []u8) ReadResult(T) {
        var res: ReadResult(T) = undefined;
        res.val = std.mem.bytesToValue(T, input[0..@sizeOf(T)]);
        res.input = input[@sizeOf(T)..];
        return res;
    }

    pub fn deserialize(input: []u8) void {
        // const tile_stride = 5 * @sizeOf(u32);
        const tile_len = read(u32, input[0..]);
        const box_len = read(u32, tile_len.input[0..]);

        std.debug.print("Tile Len: {d}\n", .{tile_len.val});
        std.debug.print("Box Len: {d}\n", .{box_len.val});

        // var idx: usize = 0;
        // var byte_idx: usize = 0;
        // while (idx < tile_len) {
        //     const x = std.mem.bytesToValue(u32, input)
        // }
    }
};
