const std = @import("std");
const log = std.log;
const mem = std.mem;
const rand = std.rand;
const time = std.time;
// const clap = @import("clap");
// const clap = @import("../zigmod/deps/git/github.com/Hejsil/zig-clap/clap.zig");
// const clap = @import("./libs/zig-clap/clap.zig");
const ppm = @import("ppm_image.zig");
const prompt = @import("prompt.zig");
const utils = @import("utils.zig");
const Vec3f = @import("vec3.zig").Vec3f;
const Camera = @import("camera.zig").Camera;
const Scene = @import("scene.zig").Scene;
const RayTracerConfig = @import("raytracer.zig").RayTracerConfig;
const multithreading = @import("multithreading.zig");

/// entry point of the application.
pub fn main() anyerror!void {
    var timer = try time.Timer.start();
    const t0 = timer.lap();

    ////////////////////////////////////////////////////////////////////////////
    // move CLI to prompt.zig when finished

    // \\-h, --help Display this help and exit.
    // \\-s, --scene <str>  An option parameter which can be specified multiple times.
    // \\--single       If true, use a single thread.
    // \\--seed <usize>     Seed for the random number generator.
    // \\--spp <usize>  Samples Per Pixel.
    // \\<str>...

    // https://github.com/Hejsil/zig-clap
    // const params = comptime clap.parseParamsComptime(
    //     \\-s, --scene <str>  An option parameter which can be specified multiple times.
    //     \\<str>...
    //     \\
    // );

    // const parsers = comptime .{
    //     .usize = clap.parsers.int(usize, 0),
    //     // .FILE = clap.parsers.string,
    //     // .INT = clap.parsers.int(usize, 10),
    // };

    // var diag = clap.Diagnostic{};
    // var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
    //     .diagnostic = &diag,
    // }) catch |err| {
    //     // report useful error and exit
    //     diag.report(std.io.getStdErr().writer(), err) catch {};
    //     return err;
    // };
    // defer res.deinit();

    // if (res.args.help) {
    //     return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    // }

    // const use_single_thread = if (res.args.single) true else false;
    const use_single_thread = true;
    // const use_single_thread = false;

    // TODO: support rendering multiple scenes with -s 18 -s 19 -s 20 (each scene has associated its own camera)
    const num_scene = @intCast(u8, try prompt.askPositiveInteger(.{ .message = "What scene do you want to render? Pick an integer 18 <= N <= 21", .default = 18 }));
    // for (res.args.scene) |s| {
    //     log.info("render scene {}", .{s});
    //     num_scene = @intCast(u8, try parseU32(s, 10));
    // }

    const width = try prompt.askPositiveInteger(.{ .message = "How wide should the image be? Pick an integer > 0", .default = 256 });

    const spp = @intCast(u8, try prompt.askPositiveInteger(.{ .message = "How many rays do you want to cast for each rendered pixel? Pick an integer > 0", .default = 8 }));

    const init_seed = try prompt.askPositiveInteger(.{ .message = "What seed do you want to use for the pseudo random number generator? Pick an integer >= 0", .default = 42 });

    // for (res.positionals) |p, i| {
    //     log.info("positional p {} i {}", .{ p, i });
    //     if (i == 0) {
    //         width = try parseU32(p, 10);
    //     }
    // }
    ////////////////////////////////////////////////////////////////////////////

    const img = ppm.Image.new(width, 16.0 / 9.0, 255);
    // const img = Image.new(1200, 3.0 / 2.0, 255); // final render setup
    log.info("PPM image: {}", .{img});

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
    } else {
        // setup for final scene
        lookfrom = Vec3f.new(13.0, 2.0, 3.0);
        focal_dist = 10.0;
        aperture = 0.1;
    }

    var camera = Camera.new(lookfrom, lookat, up, vfov, img.aspect_ratio, aperture, focal_dist);

    const gpa_config = .{ .verbose_log = false };
    var gpa = std.heap.GeneralPurposeAllocator(gpa_config){};
    defer _ = gpa.deinit();

    var gpa_allocator = gpa.allocator();

    var slice = try gpa_allocator.alloc(u8, img.size);
    defer gpa_allocator.free(slice);

    if (use_single_thread) {
        try ppm.render(&arena_allocator, slice, &prng.random(), &scene, &camera, &cfg, &img, 0, img.num_pixels);
    } else {
        const num_cores = try std.Thread.getCpuCount();
        const num_threads_per_core = 2;
        const num_threads = @intCast(u32, num_threads_per_core * num_cores);
        log.info("spawn {} threads ({} CPU cores, {} threads per core)", .{ num_threads, num_cores, num_threads_per_core });

        const pixels_per_thread = multithreading.chunkSize(img.num_pixels, num_threads);

        var threads = std.ArrayList(*std.Thread).init(gpa_allocator);
        defer threads.deinit();

        var ithread: u8 = 0;
        while (ithread < num_threads) : (ithread += 1) {
            const spawn_cfg: std.Thread.SpawnConfig = .{};
            const ctx = multithreading.ThreadContext.new(&gpa_allocator, slice, ithread, &scene, num_scene, &camera, &cfg, &img, pixels_per_thread);

            var thread = try std.Thread.spawn(spawn_cfg, ppm.renderMultiThread, .{ctx});
            try threads.append(&thread);
        }

        for (threads.items) |t| {
            t.join();
        }
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

fn filepath(allocator: *mem.Allocator, num_scene: usize, cfg: *const RayTracerConfig, img: *const ppm.Image, seed: usize) ![]const u8 {
    // spp = samples per pixels (ray casted for each pixel)
    // subpx = antialiasing by supersampling subpixel samples
    // depth = max number of rebounds for each ray
    const s = "images/scene{}-w{}-subpx{}-spp{}-depth{}-seed{}.ppm";
    const n = std.fmt.count(s, .{ num_scene, img.width, cfg.subpixels, cfg.rays_per_subsample, cfg.rebounds, seed });
    const slice = try allocator.alloc(u8, n + utils.numDigits(num_scene) + utils.numDigits(cfg.subpixels) + utils.numDigits(cfg.rays_per_subsample) + utils.numDigits(cfg.rebounds) + utils.numDigits(seed));
    return try std.fmt.bufPrint(slice, s, .{ num_scene, img.width, cfg.subpixels, cfg.rays_per_subsample, cfg.rebounds, seed });
}
