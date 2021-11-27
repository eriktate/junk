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
            return @bitCast(Simd, self);
        }
        pub inline fn fromSimd(v: Simd) Self {
            return @bitCast(Self, v);
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
    };
}

pub fn Vec2(comptime T: type) type {
    return struct { // in case of problems, maybe try changing this to 'extern struct'
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

// this implementation has an extra padding field to support simd conversions via @bitCast
pub fn Vec3(comptime T: type) type {
    return struct {
        x: T, // x: T align(16), <-- compiles but results in runtime alignment error
        y: T,
        z: T,
        // padding is required to allow bitcasting. without this compiler error: non power of 2 alignment
        _padding: T = 1,

        const Self = @This();
        pub fn init(x: T, y: T, z: T) Self {
            return .{
                .x = x,
                .y = y,
                .z = z,
            };
        }

        // fields_len = 4 rather than 3 is required to allow bitcasting with same size
        pub usingnamespace VecMethods(T, 4, Self);
    };
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
};
