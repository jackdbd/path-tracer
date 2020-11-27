const std = @import("std");
const ArrayList = std.ArrayList;
const heap = std.heap;
const mem = std.mem;
const Vec3f = @import("vec3.zig").Vec3f;
const Ray = @import("ray.zig").Ray;
const Material = @import("material.zig").Material;
const Sphere = @import("sphere.zig").Sphere;
const HitRecord = @import("sphere.zig").HitRecord;

pub const World = struct {
    spheres: ArrayList(Sphere),

    const Self = @This();

    pub fn init(allocator: *mem.Allocator) Self {
        return Self{ .spheres = ArrayList(Sphere).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.spheres.deinit();
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

test "World.init" {
    const allocator = heap.page_allocator;
    var world = World.init(allocator);
    // var arena_allocator = heap.ArenaAllocator.init(allocator);
    // defer arena_allocator.deinit();
    // var world = World.init(&arena_allocator.allocator);
    defer world.deinit();
    const r = 10.0; // radius
    // std.debug.print("\nBefore:\n{}\n", .{world.spheres});
    const albedo = Vec3f.new(1.0, 2.0, 3.0);
    const material = Material.lambertian(albedo);
    try world.spheres.append(Sphere.new(Vec3f.new(0.0, 10.0, -1.0), r, material));
    try world.spheres.append(Sphere.new(Vec3f.new(10.0, 0.0, -1.0), r * 2.0, material));
    try world.spheres.append(Sphere.new(Vec3f.new(10.0, 10.0, -1.0), r / 2.0, material));
    // for (world.spheres.items) |sphere| {
    //     std.debug.print("\nSphere:\n{}\n", .{sphere});
    // }
    expectEqual(world.spheres.items.len, 3);
}
