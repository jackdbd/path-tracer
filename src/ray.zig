const std = @import("std");
const vector = @import("./vector.zig");
const Color = vector.Color;
const Vec3 = vector.Vec3;
const Vec3f = vector.Vec3f;

/// The ray that is casted from an origin, alongside a direction.
pub const Ray = struct {
    origin: Vec3f,
    direction: Vec3f,

    const Self = @This();

    pub fn new(origin: Vec3f, direction: Vec3f) Self {
        return Self{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn pointAt(self: Self, t: f32) Vec3f {
        return self.origin.add(self.direction.mul(t));
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Ray.pointAt" {
    const r = Ray.new(Vec3f.zero(), Vec3f.one());
    const p = r.pointAt(1.0);
    expectEqual(p.x, 1.0);
    expectEqual(p.y, 1.0);
    expectEqual(p.z, 1.0);
}
