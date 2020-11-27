const std = @import("std");
const assert = std.debug.assert;
const Ray = @import("ray.zig").Ray;
const Vec3f = @import("vec3.zig").Vec3f;

/// The ray that is casted from an origin, alongside a direction.
pub const Camera = struct {
    origin: Vec3f,
    aspect_ratio: f32,
    viewport_height: f32,
    viewport_width: f32,
    focal_length: f32,
    lower_left_corner: Vec3f,
    horizontal: Vec3f,
    vertical: Vec3f,

    const Self = @This();

    /// Create a perspective camera.
    ///
    /// origin: the position of the camera. It's the "eye", the position from
    /// where we look at the scene.
    pub fn new(origin: Vec3f, aspect_ratio: f32, vh: f32, focal_length: f32) Self {
        assert(aspect_ratio > 0.0);
        assert(vh > 0.0);

        const vw = vh * aspect_ratio;
        // std.debug.print("Aspect Ratio: {}\n", .{aspect_ratio});
        // std.debug.print("Focal Length: {}\n", .{focal_length});
        // std.debug.print("Viewport W: {}, H {}\n", .{ vw, vh });

        const half_vw = Vec3f.new(vw / 2.0, 0.0, 0.0);
        const half_vh = Vec3f.new(0.0, vh / 2.0, 0.0);
        // distance from the origin of the camera and the viewport
        const d = Vec3f.new(0.0, 0.0, focal_length);

        const lower_left_corner = origin.sub(half_vw).sub(half_vh).sub(d);
        // std.debug.print("lower_left_corner {}\n", .{lower_left_corner});

        return Self{
            .origin = origin,
            .aspect_ratio = aspect_ratio,
            .focal_length = focal_length,
            .viewport_height = vh,
            .viewport_width = vw,
            .lower_left_corner = lower_left_corner,
            .horizontal = Vec3f.new(vw, 0.0, 0.0),
            .vertical = Vec3f.new(0.0, vh, 0.0),
        };
    }

    pub fn castRay(self: Self, u: f32, v: f32) Ray {
        const direction = self.lower_left_corner.add(self.horizontal.mul(u).add(self.vertical.mul(v)).sub(self.origin)).unitVector();
        return Ray.new(self.origin, direction);
    }
};

// pub fn randomInUnitDisk(r: *Random) Self {
//     return while (true) {
//         const p = Vec3f.new(2.0 * r.float(f32) - 1.0, 2.0 * r.float(f32) - 1.0, 0.0);
//         if (p.lengthSquared() < 1.0) {
//             break p;
//         }
//     } else Vec3f.zero();
// }

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Camera.new" {
    const aspect = 16.0 / 9.0;
    const vh = 2.0;
    const focal_length = 1.0;
    const camera = Camera.new(Vec3f.new(0.0, 0.0, 0.0), aspect, vh, focal_length);
    expectEqual(camera.viewport_height, vh);
    expectEqual(camera.viewport_width, vh * aspect);
    expectEqual(camera.aspect_ratio, aspect);
    expectEqual(camera.focal_length, focal_length);
}
