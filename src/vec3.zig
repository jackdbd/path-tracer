//! 3D Vector and vector operations.

const std = @import("std");
const math = std.math;

/// A 3 dimensional vector of type T.
pub fn Vec3(comptime T: type) type {

    // Beware that at the moment packed structs are still incomplete and have a
    // few bugs. For reference, see:
    // https://github.com/ziglang/zig/issues/2627
    // https://github.com/ziglang/zig/issues/3133
    return struct {
        x: T,
        y: T,
        z: T,

        const Self = @This();

        /// Create a new vector from 3 coordinates.
        pub fn new(x: T, y: T, z: T) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
            };
        }

        /// Compute the Euclidean norm, namely the length, the magnitude of the vector.
        pub fn norm(self: Self) T {
            return math.sqrt(self.lengthSquared());
        }

        /// Alias for norm.
        pub const length = norm;

        pub fn lengthSquared(self: Self) T {
            return math.pow(T, self.x, 2) + math.pow(T, self.y, 2) + math.pow(T, self.z, 2);
        }

        /// Add another vector to this one.
        pub fn add(self: Self, other: Self) Self {
            return Self.new(self.x + other.x, self.y + other.y, self.z + other.z);
        }

        /// Substraction another vector from this one.
        pub fn sub(self: Self, other: Self) Self {
            return Self.new(self.x - other.x, self.y - other.y, self.z - other.z);
        }

        /// Multiply this vector for a scalar.
        pub fn mul(self: Self, k: T) Self {
            return Self{
                .x = k * self.x,
                .y = k * self.y,
                .z = k * self.z,
            };
        }

        /// Get a normalized version of the vector, with same direction but magnitude 1.
        pub fn unitVector(self: Self) Self {
            const inv_n = 1.0 / self.norm();
            return Self.new(inv_n * self.x, inv_n * self.y, inv_n * self.z);
        }

        /// Perform the dot product between 2 vectors.
        pub fn dot(self: Self, other: Self) f32 {
            return self.x * other.x + self.y * other.y + self.z * other.z;
        }

        /// Perform the cross product between 2 vectors.
        pub fn cross(self: Self, other: Self) Self {
            return Self.new(
                self.y * other.z - self.z * other.y,
                self.z * other.x - self.x * other.z,
                self.x * other.y - self.y * other.x,
            );
        }

        /// Multiply the coordinates of two vectors.
        pub fn elementwiseMul(a: Self, b: Self) Self {
            return Self{
                .x = a.x * b.x,
                .y = a.y * b.y,
                .z = a.z * b.z,
            };
        }
    };
}

pub const Vec3f = Vec3(f32);

const epsilon = @import("constants.zig").epsilon;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Vec3f.new" {
    const v = Vec3f.new(1.0, 2.0, 3.0);
    try expectEqual(v.x, 1.0);
    try expectEqual(v.y, 2.0);
    try expectEqual(v.z, 3.0);
}

test "Vec3.length" {
    const x = 3.0;
    const y = 4.0;
    const z = 5.0;
    const expected = math.sqrt(math.pow(f32, x, 2) + math.pow(f32, y, 2) + math.pow(f32, z, 2));
    const v = Vec3f.new(x, y, z);
    try expectEqual(v.length(), expected);
}

test "Vec3f.add" {
    const a = Vec3f.new(1.0, 2.0, 3.0);
    const b = Vec3f.new(2.0, 3.0, 4.0);
    const v = a.add(b);
    try expectEqual(v.x, 3.0);
    try expectEqual(v.y, 5.0);
    try expectEqual(v.z, 7.0);
}

test "Vec3f.sub" {
    const a = Vec3f.new(2.0, 3.0, 4.0);
    const b = Vec3f.new(2.0, 4.0, 3.0);
    const v = a.sub(b);
    try expectEqual(v.x, 0.0);
    try expectEqual(v.y, -1.0);
    try expectEqual(v.z, 1.0);
}

test "unitVector" {
    const v = Vec3f.new(1.0, 2.0, 3.0);
    try expect(math.fabs(v.unitVector().length() - 1.0) < epsilon);
}

test "dot product" {
    const a = Vec3f.new(2.0, 3.0, 4.0);
    const b = Vec3f.new(5.0, 6.0, 7.0);
    const res = a.dot(b);
    try expect(res - 56 < epsilon);
    try expectEqual(res, 56);
}

test "cross product" {
    const a = Vec3f.new(1.0, 0.0, 2.0);
    const b = Vec3f.new(2.0, 1.0, 2.0);
    const v = a.cross(b);
    try expectEqual(v.x, -2.0);
    try expectEqual(v.y, 2.0);
    try expectEqual(v.z, 1.0);
}

test "Vec3f.elementwiseMul" {
    const a = Vec3f.new(2.0, 3.0, 4.0);
    const b = Vec3f.new(3.0, 4.0, 5.0);
    const v = a.elementwiseMul(b);
    try expectEqual(v.x, 6.0);
    try expectEqual(v.y, 12.0);
    try expectEqual(v.z, 20.0);
}
