const lag = @import("lag.zig");
const Vec3 = lag.Vec3(f32);

pub const BBox = struct {
    id: usize,
    pos: Vec3,
    width: f32,
    height: f32,

    pub fn init(id: usize, pos: Vec3, width: u32, height: u32) BBox {
        return BBox{
            .id = id,
            .pos = pos,
            .width = @intToFloat(f32, width),
            .height = @intToFloat(f32, height),
        };
    }

    pub fn overlaps(self: BBox, other: BBox) bool {
        const pos = self.pos;
        const overlap_x = (pos.x <= other.pos.x + other.width and pos.x >= other.pos.x) or (pos.x + self.width >= other.pos.x and pos.x + self.width < other.pos.x + other.width);
        const overlap_y = (pos.y <= other.pos.y + other.height and pos.y >= other.pos.y) or (pos.y + self.height >= other.pos.y and pos.y + self.height <= other.pos.y + other.height);

        return overlap_x and overlap_y;
    }
};
