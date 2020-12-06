const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const log = std.log;
const mem = std.mem;
const rand = std.rand;
const time = std.time;
const ArrayList = std.ArrayList;
const Thread = std.Thread;
const clap = @import("./libs/zig-clap/clap.zig");
const ppm = @import("ppm_image.zig");
const prompt = @import("prompt.zig");
const Vec3f = @import("vec3.zig").Vec3f;
const Camera = @import("camera.zig").Camera;
const Scene = @import("scene.zig").Scene;
const RayTracerConfig = @import("raytracer.zig").RayTracerConfig;
const multithreading = @import("multithreading.zig");
const numDigits = @import("utils.zig").numDigits;

const maxInt = std.math.maxInt;

fn charToDigit(c: u8) u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => maxInt(u8),
    };
}

pub fn parseU32(buf: []const u8, radix: u8) !u32 {
    var x: u32 = 0;

    for (buf) |c| {
        const digit = charToDigit(c);

        if (digit >= radix) {
            return error.InvalidChar;
        }

        // x *= radix
        if (@mulWithOverflow(u32, x, radix, &x)) {
            return error.Overflow;
        }

        // x += digit
        if (@addWithOverflow(u32, x, digit, &x)) {
            return error.Overflow;
        }
    }

    return x;
}

pub fn main() anyerror!void {
    var timer = try time.Timer.start();
    const t0 = timer.lap();

    ////////////////////////////////////////////////////////////////////////////
    // move CLI to prompt.zig when finished

    const params = comptime [_]clap.Param(clap.Help){
        // clap.parseParam("-h, --help             Display this help and exit.              ") catch unreachable,
        clap.parseParam("--single               If true, use single thread.") catch unreachable,
        clap.parseParam("--spp <NUM>            Samples Per Pixel.") catch unreachable,
        clap.parseParam("--seed <NUM>           Seed for the random number generator.") catch unreachable,
        clap.parseParam("-s, --scene <STR>...   An option parameter which can be specified multiple times.") catch unreachable,
        clap.parseParam("<POS>...") catch unreachable,
    };

    var diag: clap.Diagnostic = undefined;
    var args = clap.parse(clap.Help, &params, std.heap.page_allocator, &diag) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().outStream(), err) catch {};
        return err;
    };
    defer args.deinit();

    // TODO: implement help
    // if (args.flag("--help")) {
    //     std.debug.warn("--help\n", .{});
    // }

    var use_single_thread = false;
    if (args.flag("--single")) {
        use_single_thread = true;
        log.info("render using a single thread", .{});
    }

    var spp: u8 = 10;
    if (args.option("--spp")) |s| {
        spp = @intCast(u8, try parseU32(s, 10));
        log.info("spp (Samples Per Pixels): {}", .{spp});
    }

    var init_seed: u32 = 0;
    if (args.option("--seed")) |s| {
        init_seed = try parseU32(s, 10);
        log.info("init_seed: {}", .{init_seed});
    }

    // TODO: support rendering multiple scenes with -s 18 -s 19 -s 20 (each scene has associated its own camera)
    var num_scene: u8 = 18;
    for (args.options("--scene")) |s| {
        log.info("render scene {}", .{s});
        num_scene = @intCast(u8, try parseU32(s, 10));
    }

    var width: u32 = 0;
    for (args.positionals()) |p, i| {
        if (i == 0) {
            width = try parseU32(p, 10);
        }
    }
    ////////////////////////////////////////////////////////////////////////////

    var prng = rand.DefaultPrng.init(init_seed);

    // width = try prompt.ask_user();
    const img = ppm.Image.new(width, 16.0 / 9.0, 255);
    // const img = Image.new(1200, 3.0 / 2.0, 255); // final render setup
    log.debug("PPM image: {}", .{img});

    const cfg = RayTracerConfig{
        .subpixels = 4,
        .t_min = 0.1,
        .t_max = 1000.0,
        .rebounds = 6,
        .rays_per_subsample = spp,
    };
    log.info("Ray Tracer: {}", .{cfg});

    // TODO: discuss why using an arena allocator (or why not, and which one to use instead).
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();

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

    var camera = Camera.new(lookfrom, lookat, up, vfov, img.aspect_ratio, aperture, focal_dist);

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    var slice = try gpa.allocator.alloc(u8, img.size);

    if (use_single_thread) {
        try ppm.render(&arena.allocator, slice, &prng.random, &scene, &camera, &cfg, &img, 0, img.num_pixels);
    } else {
        const num_cores = try Thread.cpuCount();
        const num_threads_per_core = 2;
        const num_threads = @intCast(u32, num_threads_per_core * num_cores);
        log.info("spawn {} threads ({} CPU cores, {} threads per core)", .{ num_threads, num_cores, num_threads_per_core });

        const pixels_per_thread = multithreading.chunk_size(img.num_pixels, num_threads);

        var contexts = ArrayList(multithreading.ThreadContext).init(&gpa.allocator);
        defer contexts.deinit();

        var threads = ArrayList(*Thread).init(&gpa.allocator);
        defer threads.deinit();

        var ithread: u8 = 0;
        while (ithread < num_threads) : (ithread += 1) {
            const ctx = multithreading.ThreadContext.new(&gpa.allocator, slice, ithread, &scene, num_scene, &camera, &cfg, &img, pixels_per_thread);
            try contexts.append(ctx);
            const thread = try Thread.spawn(ctx, ppm.renderMultiThread);
            try threads.append(thread);
        }

        for (threads.items) |t| {
            t.wait();
        }
    }

    const ppm_header = try img.header(&gpa.allocator);
    mem.copy(u8, slice, ppm_header);

    const file_path = try filepath(&gpa.allocator, num_scene, &cfg, &img, init_seed);
    try fs.cwd().writeFile(file_path, slice);
    log.info("wrote {}", .{file_path});
    const t1 = timer.lap();
    const elapsed_s = @intToFloat(f64, t1 - t0) / time.ns_per_s;
    log.info("Program took {d:.2} seconds", .{elapsed_s});
}

fn filepath(allocator: *mem.Allocator, num_scene: u8, cfg: *const RayTracerConfig, img: *const ppm.Image, seed: u32) ![]const u8 {
    // spp = samples per pixels (ray casted for each pixel)
    // subpx = antialiasing by supersampling subpixel samples
    // depth = max number of rebounds for each ray
    const s = "images/scene{}-w{}-subpx{}-spp{}-depth{}-seed{}.ppm";
    const n = std.fmt.count(s, .{ num_scene, img.width, cfg.subpixels, cfg.rays_per_subsample, cfg.rebounds, seed });
    const slice = try allocator.alloc(u8, n + numDigits(num_scene) + numDigits(cfg.subpixels) + numDigits(cfg.rays_per_subsample) + numDigits(cfg.rebounds) + numDigits(seed));
    return try std.fmt.bufPrint(slice, s, .{ num_scene, img.width, cfg.subpixels, cfg.rays_per_subsample, cfg.rebounds, seed });
}
