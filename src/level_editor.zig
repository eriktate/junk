const std = @import("std");
const lag = @import("lag.zig");
const sprite = @import("sprite.zig");
const Manager = @import("manager.zig").Manager;
const Window = @import("window.zig").Window;
const Texture = @import("texture.zig").Texture;
const Debug = @import("debug.zig").Debug;
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
    manager: *Manager,
    debug: *Debug,

    pub fn init(manager: *Manager, win: Window, debug: *Debug, active_tileset: Texture) LevelEditor {
        return LevelEditor{
            .active_tileset = active_tileset,
            .selected_tile = Vec2.zero(),
            .lmb_pressed = false,
            .rmb_pressed = false,
            .manager = manager,
            .mode = Mode.Tile,
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
                        _ = try self.manager.add(tile);
                    }
                    return;
                },
                ShowTag.anim => return,
            }
        }

        std.debug.print("Adding tile {d}, {d} to {d}, {d}\n", .{ self.selected_tile.x, self.selected_tile.y, pos.x, pos.y });
        _ = try self.manager.add(tile);
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
        if (pressed == false or self.mode != Mode.Tile) {
            return;
        }

        const cursor_pos = self.getCursorPos();
        if (cursor_pos.x < @intToFloat(f32, self.active_tileset.width) and cursor_pos.y < @intToFloat(f32, self.active_tileset.height)) {
            self.selectTile(cursor_pos);
            return;
        }

        self.addTile(cursor_pos) catch unreachable;
    }

    pub fn handleRMB(self: *LevelEditor, pressed: bool) void {
        self.rmb_pressed = pressed;
        self.tick() catch unreachable;
    }

    pub fn tick(self: LevelEditor) !void {
        const cursor_pos = self.getCursorPos();
        if (self.lmb_pressed) {
            if (self.mode == Mode.Tile) {
                try self.addTile(cursor_pos);
            }
        }

        if (self.rmb_pressed) {
            if (self.mode == Mode.Tile) {
                self.removeTile(cursor_pos);
            }
        }
    }
};
