const lag = @import("lag.zig");
const Vec3 = lag.Vec3(f32);

const BBox = @This();
id: usize,
pos: Vec3,
offset: Vec3,
width: f32,
height: f32,

pub fn init(pos: Vec3, width: u32, height: u32) BBox {
    return BBox{
        .id = 0,
        .pos = pos,
        .width = @intToFloat(f32, width),
        .height = @intToFloat(f32, height),
        .offset = Vec3.init(0, 0, 0),
    };
}

pub fn withOffset(self: BBox, offset: Vec3) BBox {
    var box = self;
    box.offset = offset;

    return box;
}

pub fn afterOffset(self: BBox) BBox {
    var box = self;
    box.pos = self.pos.add(self.offset);
    return box;
}

pub fn setOffset(self: *BBox, offset: Vec3) void {
    self.offset = offset;
}

fn checkOverlap(self: BBox, other: BBox) bool {
    const pos = self.pos.add(self.offset);
    const other_pos = other.pos.add(other.offset);

    const overlap_x = (pos.x <= other_pos.x + other.width and pos.x >= other_pos.x) or (pos.x + self.width >= other_pos.x and pos.x + self.width < other_pos.x + other.width);
    const overlap_y = (pos.y <= other_pos.y + other.height and pos.y >= other_pos.y) or (pos.y + self.height >= other_pos.y and pos.y + self.height <= other_pos.y + other.height);

    return overlap_x and overlap_y;
}

pub fn overlaps(self: BBox, other: BBox) bool {
    return checkOverlap(self, other) or checkOverlap(other, self);
}

// TODO (etate): We might need to consider the offset here
pub fn contains(self: BBox, pos: Vec3) bool {
    return pos.x > self.pos.x and pos.x < self.pos.x + self.width and pos.y > self.pos.y and pos.y < self.pos.y + self.height;
}
