const std = @import("std");
const assert = std.debug.assert;
const vector = @import("./vector.zig");
const Vec3f = vector.Vec3f;
const Ray = @import("./ray.zig").Ray;

pub const Sphere = struct {
    center: Vec3f,
    radius: f32,

    const Self = @This();

    pub fn new(center: Vec3f, radius: f32) Self {
        assert(radius > 0.0);

        return Self{
            .center = center,
            .radius = radius,
        };
    }

    /// Find out whether the sphere was hit by a ray.
    /// The sphere is hit by a ray if 1 or 2 points of the ray are also points
    /// on the surface of the sphere. Given these known parameters:
    /// O: ray origin
    /// D: ray direction
    /// C: sphere center
    /// r: sphere radius
    /// the equation to solve is the following:
    /// t^2 * D^2 + 2 * t * D * (O - C) + (O - C) * (O - C) = r^2
    /// which can be simplified into:
    /// (t*D + O - C)^2 = r^2
    pub fn is_hit(self: Self, ray: Ray) bool {
        const oc = ray.origin.sub(self.center);
        const a = vector.dot(ray.direction, ray.direction);
        const b = vector.dot(oc, ray.direction) * 2.0;
        const c = vector.dot(oc, oc) - self.radius * self.radius;
        const discriminant = b * b - 4 * a * c;
        // std.debug.print("discriminant: {}\n", .{discriminant});
        return discriminant > 0;
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Sphere.new" {
    const center = Vec3f.new(3.0, 2.0, 0.0);
    const radius = 5.0;
    const sphere = Sphere.new(center, radius);
    expectEqual(sphere.center.x, center.x);
}

test "Sphere.is_hit" {
    // a sphere centered in the viewport (the camera eye is 0,0,0)
    const center = Vec3f.new(0, 0, -1);
    const radius = 0.5;
    const sphere = Sphere.new(center, radius);
    // a ray starting from the camera eye (0,0,0)
    const ray_origin = Vec3f.zero();
    // remember that a ray's direction is a vector of length 1
    const dir_1 = Vec3f.new(0.0, 0.0, -1.0);
    const dir_2 = Vec3f.new(0.0, 1.0, 0.0);
    const ray_1 = Ray.new(ray_origin, dir_1);
    const ray_2 = Ray.new(ray_origin, dir_2);
    expectEqual(sphere.is_hit(ray_1), true);
    expectEqual(sphere.is_hit(ray_2), false);
    // TODO: the ray is a half-line, so this ray should NOT hit the sphere
    // because it is traveling in the opposite direction.
    // const dir_3 = Vec3f.new(0.0, 0.0, 1.0);
    // const ray_3 = Ray.new(ray_origin, dir_3);
    // expectEqual(sphere.is_hit(ray_3), false);
}
