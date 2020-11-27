const std = @import("std");
const Vec3f = @import("vec3.zig").Vec3f;
const Ray = @import("ray.zig").Ray;
const Camera = @import("camera.zig").Camera;
const Material = @import("material.zig").Material;
const Sphere = @import("sphere.zig").Sphere;
const World = @import("world.zig").World;
const utils = @import("utils.zig");
const ppm = @import("ppm_image.zig");
const math = std.math;
const mem = std.mem;
const heap = std.heap;
const fmt = std.fmt;
const fs = std.fs;
const log = std.log;

var prng = std.rand.DefaultPrng.init(0);

/// Color a pixel based on surface normals.
///
/// If the ray hits an object in the 3D world, color the pixel according to the
/// surface normal passing through the point hit by the ray.
/// If the ray doesn't hit anything, color the pixel using linear interpolation.
/// RGB values are between 0.0 and 1.0.
fn colorNormal(ray: Ray, world: *const World, t_min: f32, t_max: f32, blend_start: Vec3f, blend_stop: Vec3f) Vec3f {
    const maybe_hit = world.is_hit(ray, t_min, t_max);
    if (maybe_hit) |hit| {
        // const scatter = hit.material.scatter(ray);
        const n = ray.pointAt(hit.t).sub(Vec3f.new(0.0, 0.0, -1.0)).unitVector();
        return n.add(Vec3f.new(1.0, 1.0, 1.0)).mul(0.5);
    } else {
        return utils.lerp(ray.direction, blend_start, blend_stop);
    }
}

/// Compute the radiance (intensity of light).
fn radiance(ray: Ray, world: *const World, cfg: RayTracerConfig, blend_start: Vec3f, blend_stop: Vec3f, depth: u32) Vec3f {
    const maybe_hit = world.is_hit(ray, cfg.t_min, cfg.t_max);
    if (maybe_hit) |hit| {
        if (depth < cfg.depth_max) {
            const s = Material.scatter(ray, hit, &prng.random);
            return radiance(s.ray, world, cfg, blend_start, blend_stop, depth + 1).elementwiseMul(s.attenuation);
        } else {
            return Vec3f.new(0.0, 0.0, 0.0);
        }
    } else {
        return utils.lerp(ray.direction, blend_start, blend_stop);
    }
}

/// Color a pixel based on the albedo (reflected light over incident light).
///
/// If the ray hits an object in the 3D world, color the pixel according to the
/// albedo of the point hit by the ray.
/// If the ray doesn't hit anything, color the pixel using linear interpolation.
/// RGB values are between 0.0 and 1.0.
/// https://www.scratchapixel.com/lessons/3d-basic-rendering/introduction-to-shading/diffuse-lambertian-shading
fn colorAlbedo(ray: Ray, world: *const World, t_min: f32, t_max: f32, blend_start: Vec3f, blend_stop: Vec3f) Vec3f {
    const maybe_hit = world.is_hit(ray, t_min, t_max);
    if (maybe_hit) |hit| {
        // const n = ray.pointAt(hit.t).sub(Vec3f.new(0.0, 0.0, -1.0)).unitVector();
        // return n.add(Vec3f.one()).mul(0.5);
        return switch (hit.material) {
            Material._lambertian => |mat| mat.albedo,
            Material._metal => |mat| mat.albedo,
            Material._dielectric => |_| Vec3f.new(1.0, 1.0, 1.0),
        };
    } else {
        return utils.lerp(ray.direction, blend_start, blend_stop);
    }
}

/// Setup the world with all objects.
fn setupWorld(world: *World) !void {
    log.info("setupWorld", .{});
    const random_albedo = Vec3f.new(prng.random.float(f32), prng.random.float(f32), prng.random.float(f32));
    const metal = Material.metal(random_albedo, 0.3);
    const lambertian = Material.lambertian(Vec3f.new(1.0, 0.0, 0.7));

    // ground
    try world.spheres.append(Sphere.new(Vec3f.new(0, -100.5, -1), 100, metal));
    // try world.spheres.append(Sphere.new(Vec3f.new(0, -100.5, -1), 100, Material.dielectric(1.5)));

    // try world.spheres.append(Sphere.new(Vec3f.new(1.5, -0.25, -1), 0.25, Material.lambertian(Vec3f.new(0.7, 0.6, 0.5))));
    try world.spheres.append(Sphere.new(Vec3f.new(1.5, -0.25, -1), 0.25, Material.dielectric(1.5)));
    try world.spheres.append(Sphere.new(Vec3f.new(0, 0, -1), 0.5, lambertian));

    try world.spheres.append(Sphere.new(Vec3f.new(-0.75, 0.25, -0.95), 0.15, metal));
}

/// Generate a PPM image file of w width and h height, in pixels
fn renderP3Image(allocator: *mem.Allocator, world: *World, camera: *Camera, cfg: RayTracerConfig, width: u32, height: u32) ![]const u8 {
    log.info("renderP3Image W:{} x H:{} .ppm image", .{ width, height });
    const header_mem_size = ppm.header_size(width, height);
    log.info("PPM header memory size: {}", .{header_mem_size});
    const px_mem_size = ppm.px_size();
    log.info("ASCII RGB pixel memory size: {}", .{px_mem_size});
    const data_mem_size: usize = px_mem_size * width * height;
    log.info("Data size (i.e. all pixels in .ppm image): {}", .{data_mem_size});
    const total_mem_size: usize = header_mem_size + data_mem_size;
    log.info("Total memory size for .ppm image: {}", .{total_mem_size});

    const header = try ppm.header(allocator, width, height);
    const slice = try allocator.alloc(u8, total_mem_size);
    mem.copy(u8, slice, header);

    const blend_start = Vec3f.new(1.0, 1.0, 1.0); // white
    const blend_stop = Vec3f.new(0.5, 0.7, 1.0); // blue
    // const blend_stop = Vec3f.new(1.0, 0.27, 0.0); // orange

    // This nested loop produces image data in RGB triplets.
    var idx: u32 = 0;
    const end_idx = width * height;
    while (idx < end_idx) : (idx += 1) {
        const i_col = @mod(idx, width);
        const i_row = @divTrunc(idx, width);
        // log.debug("idx:{} i_row:{} i_col:{}", .{idx, i_row, i_col});

        var sample: @TypeOf(cfg.subpixels) = 0;
        var color_accum = Vec3f.new(0.0, 0.0, 0.0);
        while (sample < cfg.subpixels) : (sample += 1) {

            // var rps: @TypeOf(cfg.rays_per_subsample) = 0;
            // while (rps < cfg.rays_per_subsample) : (rps += 1) {}

            // TODO: double-check the theory of u, v and the indices
            const u = (@intToFloat(f32, i_col) + prng.random.float(f32)) / @intToFloat(f32, width);
            const v = (@intToFloat(f32, height - i_row + 1) + prng.random.float(f32)) / @intToFloat(f32, height);
            const ray = camera.castRay(u, v);
            // const color_sample = colorNormal(ray, world, cfg.t_min, cfg.t_max, blend_start, blend_stop);
            // const color_sample = colorAlbedo(ray, world, cfg.t_min, cfg.t_max, blend_start, blend_stop);
            const color_sample = radiance(ray, world, cfg, blend_start, blend_stop, 0);
            color_accum = color_accum.add(color_sample);
        }
        color_accum = color_accum.mul(1.0 / @intToFloat(f32, cfg.subpixels));
        const col = color_accum.mul(255.99);
        // log.debug("RGB {} {} {}", .{col.x, col.y, col.z});

        const offset: usize = idx * px_mem_size;
        const ascii = try ppm.rgbToAscii(allocator, col);
        mem.copy(u8, slice[header_mem_size + offset ..], ascii);
    }
    return slice;
}

/// Configuration for the ray tracer.
///
/// subpixels: number of subpixels to collect. This supersampling is done for
/// antialiasing. Tipically for each pixel a 2x2 subpixel grid is considered, so
/// instead of 1 pixel sample we gather 4 subpixel samples and we average them.
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#antialiasing
/// https://www.kevinbeason.com/smallpt/
/// t_min, t_max: we consider a HitRecord only if t_min < t < t_max
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#surfacenormalsandmultipleobjects/anabstractionforhittableobjects
const RayTracerConfig = struct {
    subpixels: u8,
    t_min: f32,
    t_max: f32,
    depth_max: u8,
    rays_per_subsample: u8,
};

pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();
    const t0 = timer.lap();

    // const w = try utils.ask_user();
    // const w: u32 = 256;
    const w: u32 = 512;
    // const w: u32 = 1080;
    const aspect_ratio = 16.0 / 9.0;
    const h = @floatToInt(u32, @intToFloat(f32, w) / aspect_ratio);

    const cfg = RayTracerConfig{
        .subpixels = 4,
        .t_min = 0.1,
        .t_max = 1000.0,
        .depth_max = 10,
        .rays_per_subsample = 10,
    };
    log.info("Ray Tracer: {}", .{cfg});

    // TODO: discuss why using an arena allocator (or why not, and which one to use instead).
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();

    var world = World.init(&arena.allocator);
    defer world.deinit();
    try setupWorld(&world);

    const viewport_height = 2.0;
    const focal_length = 1.0;
    var camera = Camera.new(Vec3f.new(0.0, 0.0, 0.0), aspect_ratio, viewport_height, focal_length);

    // const slice = try renderP3Image(allocator, &world, &camera, cfg, w, h);
    // const slice = try renderP3Image(&gpa.allocator, &world, &camera, cfg, w, h);
    const slice = try renderP3Image(&arena.allocator, &world, &camera, cfg, w, h);

    var gpa = heap.GeneralPurposeAllocator(.{}){};

    const filepath = try ppm.filepath(&gpa.allocator, cfg.subpixels, cfg.depth_max);
    try fs.cwd().writeFile(filepath, slice);
    log.info("wrote {}", .{filepath});
    const t1 = timer.lap();
    const elapsed_s = @intToFloat(f64, t1 - t0) / std.time.ns_per_s;
    log.info("Program took {d:.2} seconds", .{elapsed_s});
}
