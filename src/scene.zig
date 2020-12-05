const std = @import("std");
const ArrayList = std.ArrayList;
const heap = std.heap;
const log = std.log;
const math = std.math;
const mem = std.mem;
const Random = std.rand.Random;
const Vec3f = @import("vec3.zig").Vec3f;
const Ray = @import("ray.zig").Ray;
const Material = @import("material.zig").Material;
const Sphere = @import("sphere.zig").Sphere;
const HitRecord = @import("sphere.zig").HitRecord;

pub const Scene = struct {
    spheres: ArrayList(Sphere),

    const Self = @This();

    pub fn init(allocator: *mem.Allocator) Self {
        return Self{ .spheres = ArrayList(Sphere).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.spheres.deinit();
    }

    fn sceneImage18_19_20(self: *Scene, n: u8) !void {
        if (n == 18) {
            log.debug("Image 18: A distant view", .{});
        } else if (n == 19) {
            log.debug("Image 19: Zooming in", .{});
        } else {
            log.debug("Image 20: Spheres with depth-of-field", .{});
        }
        const material_ground = Material.lambertian(Vec3f.new(0.8, 0.8, 0.0));
        const material_center = Material.lambertian(Vec3f.new(0.1, 0.2, 0.5));
        const material_left = Material.dielectric(1.5);
        const material_right = Material.metal(Vec3f.new(0.8, 0.6, 0.2), 0.0);

        try self.spheres.append(Sphere.new(Vec3f.new(0, -100.5, -1), 100.5, material_ground));
        try self.spheres.append(Sphere.new(Vec3f.new(0, 0, -1), 0.5, material_center));
        try self.spheres.append(Sphere.new(Vec3f.new(-1, 0, -1), 0.5, material_left));
        try self.spheres.append(Sphere.new(Vec3f.new(-1, 0, -1), -0.45, material_left));
        try self.spheres.append(Sphere.new(Vec3f.new(1, 0, -1), 0.5, material_right));
    }

    fn sceneImage21(self: *Scene, r: *Random) !void {
        log.debug("Image 21: Final scene", .{});
        const ground_material = Material.lambertian(Vec3f.new(0.5, 0.5, 0.5));
        try self.spheres.append(Sphere.new(Vec3f.new(0, -1000, 0), 1000, ground_material));

        var a: f32 = -11;
        while (a < 11) : (a += 1) {
            var b: f32 = -11;
            while (b < 11) : (b += 1) {
                const choose_mat = r.float(f32);
                const center = Vec3f.new(a + 0.9 * r.float(f32), 0.2, b + 0.9 * r.float(f32));
                if (choose_mat < 0.8) {
                    const albedo = Vec3f.new(r.float(f32), r.float(f32), r.float(f32));
                    try self.spheres.append(Sphere.new(center, 0.2, Material.lambertian(albedo)));
                } else if (choose_mat < 0.95) {
                    const albedo = Vec3f.new(r.float(f32), r.float(f32), r.float(f32));
                    const fuzziness = 0.5 * r.float(f32);
                    try self.spheres.append(Sphere.new(center, 0.2, Material.metal(albedo, fuzziness)));
                } else {
                    try self.spheres.append(Sphere.new(center, 0.2, Material.dielectric(1.5)));
                }
            }
        }

        const material1 = Material.dielectric(1.5);
        try self.spheres.append(Sphere.new(Vec3f.new(0, 1, 0), 1.0, material1));

        const material2 = Material.lambertian(Vec3f.new(0.4, 0.2, 0.1));
        try self.spheres.append(Sphere.new(Vec3f.new(-4, 1, 0), 1.0, material2));

        const material3 = Material.metal(Vec3f.new(0.7, 0.6, 0.5), 0.0);
        try self.spheres.append(Sphere.new(Vec3f.new(4, 1, 0), 1.0, material3));
    }

    pub fn setupScene(self: *Scene, r: *Random, n: u8) !void {
        if (n == 18 or n == 19 or n == 20) {
            try self.sceneImage18_19_20(n);
        } else {
            try self.sceneImage21(r);
        }
    }

    pub fn is_hit(self: *const Self, ray: Ray, t_min: f32, t_max: f32) ?HitRecord {
        var maybe_hit: ?HitRecord = null;
        var closest_so_far = t_max;

        for (self.spheres.items) |sphere| {
            if (sphere.is_hit(ray, t_min, t_max)) |hit_rec| {
                if (hit_rec.t < closest_so_far) {
                    maybe_hit = hit_rec;
                    closest_so_far = hit_rec.t;
                }
            }
        }

        return maybe_hit;
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Scene.init" {
    const allocator = heap.page_allocator;
    var scene = Scene.init(allocator);
    defer scene.deinit();

    const r = 10.0; // radius
    const albedo = Vec3f.new(1.0, 2.0, 3.0);
    const material = Material.lambertian(albedo);
    try scene.spheres.append(Sphere.new(Vec3f.new(0.0, 10.0, -1.0), r, material));
    try scene.spheres.append(Sphere.new(Vec3f.new(10.0, 0.0, -1.0), r * 2.0, material));
    try scene.spheres.append(Sphere.new(Vec3f.new(10.0, 10.0, -1.0), r / 2.0, material));
    expectEqual(scene.spheres.items.len, 3);
}
