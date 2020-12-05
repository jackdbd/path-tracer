const std = @import("std");
const Vec3f = @import("vec3.zig").Vec3f;
const Camera = @import("camera.zig").Camera;
const Scene = @import("scene.zig").Scene;
const RayTracerConfig = @import("raytracer.zig").RayTracerConfig;
const ppm = @import("ppm_image.zig");
const prompt = @import("prompt.zig");
const heap = std.heap;
const fs = std.fs;
const log = std.log;

pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();
    const t0 = timer.lap();

    var prng = std.rand.DefaultPrng.init(0);

    // const w = try prompt.ask_user();
    // const w: u32 = 256;
    const w: u32 = 512;
    // const w: u32 = 1080;
    const aspect_ratio = 16.0 / 9.0;

    // setup for final scene
    // const w: u32 = 1200;
    // const aspect_ratio = 3.0 / 2.0;

    const h = @floatToInt(u32, @intToFloat(f32, w) / aspect_ratio);

    const cfg = RayTracerConfig{
        .subpixels = 1,
        .t_min = 0.1,
        .t_max = 1000.0,
        .rebounds = 6,
        .rays_per_subsample = 10,
    };
    log.info("Ray Tracer: {}", .{cfg});

    // TODO: discuss why using an arena allocator (or why not, and which one to use instead).
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();

    const num_scene: u8 = 19;
    var scene = Scene.init(&arena.allocator);
    defer scene.deinit();
    try scene.setupScene(&prng.random, @intCast(u8, num_scene));

    var lookfrom = Vec3f.new(0.0, 0.0, 0.0);
    const lookat = Vec3f.new(0.0, 0.0, -1.0);
    const up = Vec3f.new(0.0, 1.0, 0.0);
    var vfov: f32 = 20.0;
    var focal_dist: f32 = undefined;
    var aperture: f32 = 1.0;

    if (num_scene == 18) {
        lookfrom = Vec3f.new(-2.0, 2.0, 1.0);
        vfov = 90.0;
        focal_dist = lookfrom.sub(lookat).length();
        aperture = 0.2;
    } else if (num_scene == 19) {
        lookfrom = Vec3f.new(-2.0, 2.0, 1.0);
        focal_dist = lookfrom.sub(lookat).length();
        aperture = 0.2;
    } else if (num_scene == 20) {
        lookfrom = Vec3f.new(3.0, 3.0, 2.0);
        focal_dist = lookfrom.sub(lookat).length();
        aperture = 2.0;
    } else {
        // setup for final scene
        lookfrom = Vec3f.new(13.0, 2.0, 3.0);
        focal_dist = 10.0;
        aperture = 0.1;
    }

    var camera = Camera.new(lookfrom, lookat, up, vfov, aspect_ratio, aperture, focal_dist);
    log.debug("camera: {}", .{camera});

    const slice = try ppm.render(&arena.allocator, &prng.random, &scene, &camera, cfg, w, h);

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const filepath = try ppm.filepath(&gpa.allocator, num_scene, cfg.subpixels, cfg.rays_per_subsample, cfg.rebounds);
    try fs.cwd().writeFile(filepath, slice);
    log.info("wrote {}", .{filepath});
    const t1 = timer.lap();
    const elapsed_s = @intToFloat(f64, t1 - t0) / std.time.ns_per_s;
    log.info("Program took {d:.2} seconds", .{elapsed_s});
}
