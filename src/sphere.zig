const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const vec3 = @import("vec3.zig");
const Vec3f = vec3.Vec3f;
const Ray = @import("ray.zig").Ray;
const Material = @import("material.zig").Material;
const Dielectric = @import("material.zig").Dielectric;
const epsilon = @import("constants.zig").epsilon;

/// Record that represents a hit by a ray.
///
/// p: 3D point hit by a ray
/// n: surface normal
/// t: parameter to discard rays that hit the object outside a a give interval.
///    A hit counts only if tmin < t < tmax
/// front_face: whether the object was hit on the front face (i.e. by an
///             external ray) or on the back face (i.e. by an internal ray).
/// material: the Material of the object where the ray hit.
pub const HitRecord = struct {
    p: Vec3f,
    n: Vec3f,
    t: f32,
    front_face: bool,
    material: Material,
};

pub fn is_front_face(ray: Ray, outward_normal: Vec3f) bool {
    const front_face = ray.direction.dot(outward_normal) < 0;
    // std.debug.print("front_face: {}\n", .{front_face});
    // normal = front_face ? outward_normal :-outward_normal;
    return front_face;
}

pub const Sphere = struct {
    center: Vec3f,
    radius: f32,
    material: Material,

    const Self = @This();

    pub fn new(center: Vec3f, radius: f32, material: Material) Self {
        // assert(radius > 0.0 or @TypeOf(material._dielectric) == Dielectric);

        return Self{
            .center = center,
            .radius = radius,
            .material = material,
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
    pub fn is_hit(self: Self, ray: Ray, t_min: f32, t_max: f32) ?HitRecord {
        const oc = ray.origin.sub(self.center);
        // const a = ray.direction.dot(ray.direction);
        // The dot product of a vector with itself gives the length squared of
        // that vector.
        const a = ray.direction.lengthSquared();
        // const b = oc.dot(ray.direction) * 2.0;
        const half_b = oc.dot(ray.direction);
        // const c = oc.dot(oc) - self.radius * self.radius;
        const c = oc.lengthSquared() - self.radius * self.radius;
        // const discriminant = b * b - 4 * a * c;
        const discriminant = half_b * half_b - a * c;
        // std.debug.print("discriminant: {}\n", .{discriminant});
        if (discriminant < 0.0) {
            return null;
        } else {
            // return (-b - math.sqrt(discriminant) ) / (2.0*a);
            const sqrtd = math.sqrt(discriminant);
            const x1 = (-half_b - sqrtd) / a;
            const x2 = (-half_b + sqrtd) / a;

            // For now let's ignore the solution x2
            const t = x1;
            if (t < t_max and t > t_min) {
                const p = ray.pointAt(t);
                const outward_normal = p.sub(self.center).mul(1.0 / self.radius).unitVector();
                assert(math.fabs(outward_normal.length() - 1.0) < epsilon);
                const front_face = is_front_face(ray, outward_normal);

                return HitRecord{
                    .p = p,
                    .n = outward_normal,
                    .t = t,
                    .front_face = front_face,
                    .material = self.material,
                };
            } else {
                return null;
            }
        }
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Sphere.new" {
    const center = Vec3f.new(3.0, 2.0, 0.0);
    const radius = 5.0;
    const albedo = Vec3f.new(1.0, 2.0, 3.0);
    const sphere = Sphere.new(center, radius, Material.lambertian(albedo));
    expectEqual(sphere.center.x, center.x);
}

test "Sphere.is_hit" {
    // a sphere centered in the viewport (the camera eye is 0,0,0)
    const center = Vec3f.new(0, 0, -1);
    const radius = 0.5;
    const albedo = Vec3f.new(1.0, 2.0, 3.0);
    const sphere = Sphere.new(center, radius, Material.lambertian(albedo));
    // a ray starting from the camera eye (0,0,0)
    const ray_origin = Vec3f.new(0.0, 0.0, 0.0);
    // remember that a ray's direction is a vector of length 1
    const dir_1 = Vec3f.new(0.0, 0.0, -1.0);
    const dir_2 = Vec3f.new(0.0, 1.0, 0.0);
    const ray_1 = Ray.new(ray_origin, dir_1);
    const ray_2 = Ray.new(ray_origin, dir_2);
    const t_min = 0.001;
    const t_max = 10000.0;

    const x = sphere.is_hit(ray_1, t_min, t_max);
    // expect(x != -1.0);
    expectEqual(sphere.is_hit(ray_2, t_min, t_max), null);
    // TODO: the ray is a half-line, so this ray should NOT hit the sphere
    // because it is traveling in the opposite direction.
    // const dir_3 = Vec3f.new(0.0, 0.0, 1.0);
    // const ray_3 = Ray.new(ray_origin, dir_3);
    // expectEqual(sphere.is_hit(ray_3), false);
}
