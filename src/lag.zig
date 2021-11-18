pub fn Vec2(comptime T: type) type {
    return struct {
        x: T,
        y: T,

        pub fn init(x: T, y: T) Vec2(T) {
            return Vec2(T){
                .x = x,
                .y = y,
            };
        }

        pub fn zero() Vec2(T) {
            return Vec2(T){
                .x = 0,
                .y = 0,
            };
        }

        pub fn add(self: Vec2(T), other: Vec2(T)) Vec2(T) {
            return Vec2(T){
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }

        pub fn sub(self: Vec2(T), other: Vec2(T)) Vec2(T) {
            return Vec2(T){
                .x = self.x - other.x,
                .y = self.y - other.y,
            };
        }

        pub fn scale(self: Vec2(T), scalar: f32) Vec2(T) {
            return Vec2(T){
                .x = self.x * scalar,
                .y = self.y * scalar,
            };
        }

        pub fn mag(self: Vec2(T)) f32 {
            return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        }

        pub fn unit(self: Vec2(T)) Vec2(T) {
            return self.scale(1 / self.mag());
        }

        pub fn eq(self: Vec2(T), other: Vec2(T)) bool {
            return self.x == other.x and self.y == other.y;
        }
    };
}

pub fn Vec3(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Vec3(T) {
            return Vec3(T){
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub fn zero() Vec3(T) {
            return Vec3(T){
                .x = 0,
                .y = 0,
                .z = 0,
            };
        }

        pub fn add(self: Vec3(T), other: Vec3(T)) Vec3(T) {
            return Vec3(T){
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
            };
        }

        pub fn sub(self: Vec3(T), other: Vec3(T)) Vec3(T) {
            return Vec3(T){
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
            };
        }

        pub fn scale(self: Vec3(T), scalar: f32) Vec3(T) {
            return Vec3(T){
                .x = self.x * scalar,
                .y = self.y * scalar,
                .z = self.z * scalar,
            };
        }

        pub fn mag(self: Vec3(T)) f32 {
            return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        }

        pub fn unit(self: Vec3(T)) Vec3(T) {
            return self.scale(1 / self.mag());
        }

        pub fn eq(self: Vec3(T), other: Vec3(T)) bool {
            return self.x == other.x and self.y == other.y and self.z == other.z;
        }
    };
}
