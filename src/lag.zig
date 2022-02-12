const std = @import("std");

pub fn VecMethods(comptime T: type, comptime fields_len: u8, comptime Self: type) type {
    return struct {
        const A = [fields_len]T;
        pub inline fn asArray(self: Self) A {
            return @bitCast(A, self);
        }
        pub inline fn fromArray(a: A) Self {
            return @bitCast(Self, a);
        }

        const Simd = std.meta.Vector(fields_len, T);
        pub inline fn asSimd(self: Self) Simd {
            return @as(Simd, @bitCast(A, self));
        }
        pub inline fn fromSimd(v: Simd) Self {
            return @bitCast(Self, @as(A, v));
        }

        pub fn add(self: Self, other: Self) Self {
            return fromSimd(self.asSimd() + other.asSimd());
        }

        pub fn sub(self: Self, other: Self) Self {
            return fromSimd(self.asSimd() - other.asSimd());
        }

        pub fn scale(self: Self, scalar: T) Self {
            return fromSimd(self.asSimd() * @splat(fields_len, scalar));
        }

        pub fn mag(self: Self) T {
            return @sqrt(@reduce(.Add, self.asSimd() * self.asSimd()));
        }

        pub fn unit(self: Self) Self {
            return self.scale(1 / self.mag());
        }

        pub fn eq(self: Self, other: Self) bool {
            return @reduce(.And, self.asSimd() == other.asSimd());
        }

        pub fn zero() Self {
            return fromArray([1]T{0} ** fields_len);
        }

        pub fn dot(self: Self, other: Self) T {
            return @sqrt(@reduce(.Add, self.asSimd() * other.asSimd()));
        }
    };
}

pub fn Vec2(comptime T: type) type {
    return extern struct {
        x: T,
        y: T,

        const Self = @This();
        pub fn init(x: T, y: T) Self {
            return .{
                .x = x,
                .y = y,
            };
        }

        pub usingnamespace VecMethods(T, 2, Self);
    };
}

pub fn Vec3(comptime T: type) type {
    return extern struct {
        x: T,
        y: T,
        z: T,

        const Self = @This();
        pub fn init(x: T, y: T, z: T) Self {
            return .{
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub usingnamespace VecMethods(T, 3, Self);
    };
}

test "simd bitcast" {
    const V3 = extern struct { x: u32, y: u32, z: u32 };
    const init = [1]u32{0} ** 3;
    const v3 = @bitCast(V3, init);
    const u32x3 = std.meta.Vector(3, u32);
    _ = @as(u32x3, @bitCast([3]u32, v3));
}

pub const Mat4 = struct {
    data: [16]f32,

    pub fn identity() Mat4 {
        return Mat4{
            .data = [16]f32{
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1,
            },
        };
    }

    pub fn orthographic(t: f32, l: f32, b: f32, r: f32) Mat4 {
        return Mat4{
            .data = [16]f32{
                2 / (r - l),          0,                    0, 0,
                0,                    2 / (t - b),          0, 0,
                0,                    0,                    1, 0,
                -((r + l) / (r - l)), -((t + b) / (t - b)), 0, 1,
            },
        };
    }

    pub fn transform(self: Mat4, in: Vec3(f32)) Vec3(f32) {
        return Vec3(f32){
            .x = Vec3(f32).init(self.data[0], self.data[4], self.data[2]).dot(in),
            .y = Vec3(f32).init(self.data[4], self.data[5], self.data[6]).dot(in),
            .z = Vec3(f32).init(self.data[8], self.data[9], self.data[10]).dot(in),
        };
    }
};
