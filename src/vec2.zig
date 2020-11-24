const std = @import("std");
const math = std.math;
const assert = std.debug.assert;

/// A 2 dimensional vector.
pub fn Vec2(comptime T: type) type {
    return packed struct {
        x: T,
        y: T,

        const Self = @This();

        // Create a new vector from 2 coordinates.
        pub fn new(x: T, y: T) Self {
            return Self{ .x = x, .y = y };
        }
    };
}

// type aliases
pub const vec2 = Vec2(f32);
pub const vec2i = Vec2(i32);
pub const vec2_f64 = Vec2(f64);
pub const vec2_i64 = Vec2(i64);

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// const epsilon: f32 = 0.00001; // or 1e-5

test "vec2.new" {
    const v = vec2.new(1.0, 2.0);
    expectEqual(@TypeOf(v.x), f32);
    expectEqual(@TypeOf(v.y), f32);
    expectEqual(v.x, 1.0);
    expectEqual(v.y, 2.0);
}

test "vec2i.new" {
    const v = vec2i.new(1, 2);
    expectEqual(@TypeOf(v.x), i32);
    expectEqual(@TypeOf(v.y), i32);
    expectEqual(v.x, 1);
    expectEqual(v.y, 2);
}
