const std = @import("std");
const log = std.log;
const mem = std.mem;
const rand = std.rand;
const time = std.time;
const clap = @import("clap");
const inquirer = @import("inquirer");

const UserError = @import("./errors.zig").UserError;
const prompt = @import("./prompt.zig");
const utils = @import("./utils.zig");
const Vec3f = @import("./vec3.zig").Vec3f;
const Camera = @import("./camera.zig").Camera;
const Scene = @import("./scene.zig").Scene;
const RayTracerConfig = @import("./raytracer.zig").RayTracerConfig;
const multithreading = @import("./multithreading.zig");
const Image = @import("./render_targets/ppm_image.zig").Image;
const ppm_renderer = @import("./renderers/ppm_image.zig");

/// entry point of the application.
pub fn main() anyerror!void {
    var timer = try time.Timer.start();
    const t0 = timer.lap();

    const gpa_config = .{ .thread_safe = true, .verbose_log = false };
    var gpa = std.heap.GeneralPurposeAllocator(gpa_config){};
    defer _ = gpa.deinit();

    var gpa_allocator = gpa.allocator();

    const in = std.io.getStdIn().reader();
    const out = std.io.getStdOut().writer();

    const use_multithreaded_version = try inquirer.forConfirm(out, in, "Use multi-threaded version?", gpa_allocator);

    // const scene_string = try inquirer.forString(out, in, "Which scene you want to render (18, 19, 20, 21)?", gpa_allocator, null);
    // const num_scene = try std.fmt.parseInt(u8, scene_string, 10);

    ////////////////////////////////////////////////////////////////////////////

    // const use_single_thread = if (res.args.single) true else false;

    // TODO: support rendering multiple scenes with -s 18 -s 19 -s 20 (each scene has associated its own camera)
    // const num_scene = @intCast(u8, try prompt.askPositiveInteger(.{ .message = "What scene do you want to render? Pick an integer 18 <= N <= 21", .default = 18 }));
    // for (res.args.scene) |s| {
    //     log.info("render scene {}", .{s});
    //     num_scene = @intCast(u8, try parseU32(s, 10));
    // }

    const n_scene = try inquirer.forEnum(out, in, "Which scene do you want to render?", gpa_allocator, enum { @"18", @"19", @"20", Final }, .@"18");
    const num_scene = switch (n_scene) {
        .@"18" => @as(u8, 18),
        .@"19" => @as(u8, 19),
        .@"20" => @as(u8, 20),
        .Final => @as(u8, 21),
    };

    const width_string = try inquirer.forString(out, in, "How wide should the image be? Pick an integer > 0", gpa_allocator, "256");
    const width = try std.fmt.parseInt(u32, width_string, 10);
    // const width = try prompt.askPositiveInteger(.{ .message = "How wide should the image be? Pick an integer > 0", .default = 256 });

    // const spp = @intCast(u8, try prompt.askPositiveInteger(.{ .message = "How many rays do you want to cast for each rendered pixel? Pick an integer > 0", .default = 8 }));
    const spp_string = try inquirer.forString(out, in, "How many rays do you want to cast for each rendered pixel? Pick an integer > 0", gpa_allocator, "8");
    const spp = try std.fmt.parseInt(u8, spp_string, 10);

    const init_seed_string = try inquirer.forString(out, in, "What seed do you want to use for the pseudo random number generator? Pick an integer >= 0", gpa_allocator, "42");
    const init_seed = try std.fmt.parseInt(u32, init_seed_string, 10);
    // const init_seed = try prompt.askPositiveInteger(.{ .message = "What seed do you want to use for the pseudo random number generator? Pick an integer >= 0", .default = 42 });

    // for (res.positionals) |p, i| {
    //     log.info("positional p {} i {}", .{ p, i });
    //     if (i == 0) {
    //         width = try parseU32(p, 10);
    //     }
    // }
    ////////////////////////////////////////////////////////////////////////////

    const img = Image.new(.{ .width = width, .aspect_ratio = 16.0 / 9.0, .max_px_value = 255 });

    // final render setup
    // const img = Image.new(.{ .width = 1200, .aspect_ratio = 3.0 / 2.0, .max_px_value = 255 });

    log.info("PPM image to render: {}", .{img});

    const cfg = RayTracerConfig{
        .subpixels = 4,
        .t_min = 0.1,
        .t_max = 1000.0,
        .rebounds = 6,
        .rays_per_subsample = spp,
    };
    log.info("Ray Tracer: {}", .{cfg});

    // TODO: discuss why using an arena allocator (or why not, and which one to use instead).
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var arena_allocator = arena.allocator();

    var prng = rand.DefaultPrng.init(init_seed);

    var scene = Scene.init(arena_allocator);
    defer scene.deinit();

    try scene.setupScene(&prng.random(), @intCast(u8, num_scene));

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
    } else if (num_scene == 21) {
        // setup for final scene
        lookfrom = Vec3f.new(13.0, 2.0, 3.0);
        focal_dist = 10.0;
        aperture = 0.1;
    } else {
        return UserError.SceneNotAvailable;
    }

    var camera = Camera.new(lookfrom, lookat, up, vfov, img.aspect_ratio, aperture, focal_dist);

    // TODO: maybe use a std.heap.FixedBufferAllocator for the image?
    var slice = try gpa_allocator.alloc(u8, img.size);
    defer gpa_allocator.free(slice);

    if (use_multithreaded_version) {
        const num_cores = try std.Thread.getCpuCount();
        const num_threads_per_core = 2;
        const num_threads = num_threads_per_core * num_cores;
        // const num_threads = @intCast(u32, num_threads_per_core * num_cores);
        log.info("spawn {d} threads ({d} CPU cores, {d} threads per core)", .{ num_threads, num_cores, num_threads_per_core });

        const pixels_per_thread = multithreading.chunkSize(img.num_pixels, num_threads);
        log.info("pixels_per_thread {d}", .{pixels_per_thread});

        var threads = std.ArrayList(std.Thread).init(gpa_allocator);
        defer threads.deinit();

        var idx_thread: u8 = 0;
        while (idx_thread < num_threads) : (idx_thread += 1) {
            const spawn_cfg: std.Thread.SpawnConfig = .{};
            const ctx = multithreading.ThreadContext.new(&gpa_allocator, slice, idx_thread, &scene, num_scene, &camera, &cfg, &img, pixels_per_thread);
            var thread = try std.Thread.spawn(spawn_cfg, ppm_renderer.renderMultiThread, .{ctx});
            try threads.append(thread);
        }

        for (threads.items) |t| {
            t.join();
        }
    } else {
        try ppm_renderer.render(.{
            .allocator = &arena_allocator,
            .camera = &camera,
            .img = &img,
            .istart = 0,
            .istop = img.num_pixels,
            .r = &prng.random(),
            .ray_tracer_config = &cfg,
            .scene = &scene,
            .slice = slice,
        });
    }

    const ppm_header = try img.header(&gpa_allocator);
    defer gpa_allocator.free(ppm_header);
    mem.copy(u8, slice, ppm_header);

    const file_path = try filepath(&gpa_allocator, num_scene, &cfg, &img, init_seed);
    defer gpa_allocator.free(file_path);

    try std.fs.cwd().writeFile(file_path, slice);
    log.info("wrote {s}", .{file_path});
    const t1 = timer.lap();
    const elapsed_s = @intToFloat(f64, t1 - t0) / time.ns_per_s;
    log.info("Program took {d:.2} seconds", .{elapsed_s});
}

// fn filepath(allocator: *mem.Allocator, num_scene: usize, cfg: *const RayTracerConfig, img: *const ppm.Image, seed: usize) ![]const u8 {
fn filepath(allocator: *mem.Allocator, num_scene: usize, cfg: *const RayTracerConfig, img: *const Image, seed: usize) ![]const u8 {
    // spp = samples per pixels (ray casted for each pixel)
    // subpx = antialiasing by supersampling subpixel samples
    // depth = max number of rebounds for each ray
    const s = "images/scene{}-w{}-subpx{}-spp{}-depth{}-seed{}.ppm";
    const n = std.fmt.count(s, .{ num_scene, img.width, cfg.subpixels, cfg.rays_per_subsample, cfg.rebounds, seed });
    const slice = try allocator.alloc(u8, n + utils.numDigits(num_scene) + utils.numDigits(cfg.subpixels) + utils.numDigits(cfg.rays_per_subsample) + utils.numDigits(cfg.rebounds) + utils.numDigits(seed));
    return try std.fmt.bufPrint(slice, s, .{ num_scene, img.width, cfg.subpixels, cfg.rays_per_subsample, cfg.rebounds, seed });
}
