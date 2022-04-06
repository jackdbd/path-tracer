const std = @import("std");
const log = std.log;
const math = std.math;
const Random = std.rand.Random;
const pow = std.math.pow;

const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

const Ray = @import("ray.zig").Ray;
const Vec3f = @import("vec3.zig").Vec3f;
const epsilon = @import("constants.zig").epsilon;
const degreesToRadians = @import("utils.zig").degreesToRadians;

pub const Camera = struct {
    aperture: f32,
    aspect_ratio: f32,
    focus_dist: f32,
    horizontal: Vec3f,
    lens_radius: f32,
    lookat: Vec3f,
    lookfrom: Vec3f,
    lower_left_corner: Vec3f,
    u: Vec3f,
    v: Vec3f,
    vertical: Vec3f,
    viewport_height: f32,
    viewport_width: f32,
    vup: Vec3f,

    const Self = @This();

    /// Create a perspective camera.
    ///
    /// lookfrom: the "eye", the position from where we look at the scene.
    /// lookat: the point the camera looks at.
    /// vup: up direction of the camera. If it's not (0,1,0) the camera is tilted.
    /// vfov: vertical field of view (in degrees).
    /// aspect_ratio: ratio between width and height of the image the camera
    /// will generate.
    /// aperture: hole to control how big the camera lens is. It affects defocus
    /// blur (aka depth of field).
    /// focus_dist: distance between the projection point and the plane where
    /// everything is in perfect focus.
    pub fn new(lookfrom: Vec3f, lookat: Vec3f, vup: Vec3f, vfov: f32, aspect_ratio: f32, aperture: f32, focus_dist: f32) Self {
        assert(math.fabs(vup.length() - 1.0) < epsilon);
        assert(vfov > 0.0);
        assert(aspect_ratio > 0.0);
        assert(aperture > 0.0);
        assert(focus_dist > 0.0);

        const theta = degreesToRadians(vfov);
        const h = math.tan(theta / 2);

        const vh = 2 * h;
        const vw = vh * aspect_ratio;

        // (u, v, w): orthonormal basis that describes the camera orientation.
        const w = lookfrom.sub(lookat).unitVector();
        const u = vup.cross(w).unitVector();
        const v = w.cross(u);
        assert(math.fabs(v.length() - 1.0) < epsilon);

        // log.debug("Aspect Ratio: {d:.2}", .{aspect_ratio});
        // log.debug("Field of View (vertical, in degrees): {d:.1}", .{vfov});
        // const exe_name = fmt.allocPrint(b.allocator, "day{:0>2}", .{ day }) catch unreachable;
        // log.debug("Focus distance: {d:.2}", .{focus_dist});
        // log.debug("Viewport W: {d:.2}, H {d:.2}", .{ vw, vh });

        const horizontal = u.mul(vw).mul(focus_dist);
        const vertical = v.mul(vh).mul(focus_dist);
        const half_vw = horizontal.mul(0.5);
        const half_vh = vertical.mul(0.5);
        const lower_left_corner = lookfrom.sub(half_vw).sub(half_vh).sub(w.mul(focus_dist));

        const lens_radius = aperture / 2.0;

        return Self{
            .aperture = aperture,
            .aspect_ratio = aspect_ratio,
            .focus_dist = focus_dist,
            .horizontal = horizontal,
            .lens_radius = lens_radius,
            .lookat = lookat,
            .lookfrom = lookfrom,
            .lower_left_corner = lower_left_corner,
            .u = u,
            .v = v,
            .vertical = vertical,
            .viewport_height = vh,
            .viewport_width = vw,
            .vup = vup,
        };
    }

    pub fn castRay(self: Self, s: f32, t: f32, r: *Random) Ray {
        const rd = randomVectorInUnitDisk(r).mul(self.lens_radius);
        const offset = self.u.mul(rd.x).add(self.v.mul(rd.y));
        const origin = self.lookfrom.add(offset);
        const direction = self.lower_left_corner.add(self.horizontal.mul(s)).add(self.vertical.mul(t)).sub(self.lookfrom).sub(offset).unitVector();
        assert(math.fabs(direction.length() - 1.0) < epsilon);
        return Ray.new(origin, direction);
    }
};

/// Random vector that falls inside a disk of a unit radius.
/// This is used when creating rays, so they start from a random origin that
/// lies on the camera lens.
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#defocusblur/generatingsamplerays
pub fn randomVectorInUnitDisk(r: *Random) Vec3f {
    while (true) {
        const p = Vec3f.new(2.0 * r.float(f32) - 1.0, 2.0 * r.float(f32) - 1.0, 0.0);
        if (p.lengthSquared() < 1.0) {
            return p;
        }
    }
}

test "camera.randomVectorInUnitDisk() has length <= 1" {
    const seed = 0;
    var prng = std.rand.DefaultPrng.init(seed);
    const v = randomVectorInUnitDisk(&prng.random());
    const squared = pow(f32, v.x, 2) + pow(f32, v.y, 2) + pow(f32, v.z, 2);
    const r = std.math.sqrt(squared);
    try expect(r <= @as(f32, 1.0));
}
