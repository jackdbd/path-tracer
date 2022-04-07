//! Renderer and utilities to render a scene to a .ppm file.

const std = @import("std");
const log = std.log;
const assert = std.debug.assert;

const Camera = @import("../camera.zig").Camera;
const illumination = @import("../illumination.zig");
const Image = @import("../render_targets/ppm_image.zig").Image;
const RayTracerConfig = @import("../raytracer.zig").RayTracerConfig;
const Scene = @import("../scene.zig").Scene;
const ThreadContext = @import("../multithreading.zig").ThreadContext;
const Vec3f = @import("../vec3.zig").Vec3f;

/// Configuration for the .ppm image renderer.
pub const Config = struct {
    allocator: *std.mem.Allocator,
    camera: *Camera,
    img: *const Image,
    istart: usize,
    istop: usize,
    r: *std.rand.Random,
    ray_tracer_config: *const RayTracerConfig,
    slice: []u8,
    scene: *Scene,
};

/// Renders a scene to a .ppm image file, using the given camera and ray tracer.
/// This code runs in a single thread.
pub fn render(cfg: Config) !void {
    const allocator = cfg.allocator;
    // log.debug("allocator {*}", .{allocator.ptr});
    const camera = cfg.camera;
    const istart = cfg.istart;
    const istop = cfg.istop;
    const img = cfg.img;
    const r = cfg.r;
    const scene = cfg.scene;
    const slice = cfg.slice;
    // log.debug("slice {*}", .{slice.ptr});
    const ray_tracer_config = cfg.ray_tracer_config;
    const subpixels = ray_tracer_config.subpixels;
    const rays_per_subsample = ray_tracer_config.rays_per_subsample;

    // log.debug("render pixels [{d}-{d}) (of {d})", .{ istart, istop, img.num_pixels });
    var idx: usize = istart;
    var progress = std.Progress{};
    const root_node = try progress.start("rendering pixel", istop + 1);
    while (idx < istop) : (idx += 1) {
        const i_col = @mod(idx, img.width);
        const i_row = @divTrunc(idx, img.width);
        // log.debug("idx {d} i_row {d} i_col {d}", .{idx, i_row, i_col});
        // progress.log("idx {d} i_row {d} i_col {d}\n", .{idx, i_row, i_col});

        var sample: @TypeOf(subpixels) = 0;
        var color_accum = Vec3f.new(0.0, 0.0, 0.0);
        while (sample < subpixels) : (sample += 1) {
            var rps: @TypeOf(rays_per_subsample) = 0;
            while (rps < rays_per_subsample) : (rps += 1) {
                // TODO: double-check the theory of u, v and the indices
                const u = (@intToFloat(f32, i_col) + r.float(f32)) / @intToFloat(f32, img.width);
                const v = (@intToFloat(f32, img.height - i_row + 1) + r.float(f32)) / @intToFloat(f32, img.height);
                const ray = camera.castRay(u, v, r);
                // const color_sample = try illumination.colorNormal(ray, scene, ray_tracer_config.t_min, ray_tracer_config.t_max, img.blend_start, img.blend_stop);
                // const color_sample = try illumination.colorAlbedo(ray, scene, ray_tracer_config.t_min, ray_tracer_config.t_max, img.blend_start, img.blend_stop);
                const color_sample = try illumination.radiance(r, ray, scene, ray_tracer_config, img.blend_start, img.blend_stop, ray_tracer_config.rebounds);
                color_accum = color_accum.add(color_sample);
            }
        }
        color_accum = color_accum.mul(1.0 / @intToFloat(f32, subpixels)).mul(1.0 / @intToFloat(f32, rays_per_subsample));
        // color_accum = color_accum.unitVector();
        // const col = color_accum.mul(255.99);
        const max_val_f = @intToFloat(f32, img.max_px_value);
        const col = color_accum.mul(max_val_f);

        assert(col.x <= max_val_f and col.y <= max_val_f and col.z <= max_val_f);

        const ascii = try img.rgbToAscii(allocator, col);
        defer allocator.free(ascii);

        const offset: usize = idx * img.px_size;
        std.mem.copy(u8, slice[img.header_size + offset ..], ascii);

        root_node.completeOne();
    }
    root_node.end();
}

/// Renders a portion of the scene to a portion of the .ppm image file.
/// This code runs in many OS threads.
pub fn renderMultiThread(ctx: ThreadContext) !void {
    const ithread = ctx.ithread;
    const num_pixels = ctx.img.num_pixels;
    const pixels_per_thread = ctx.pixels_per_thread;

    var timer = try std.time.Timer.start();
    const t0 = timer.lap();

    // This thread processes pixels from istart (included) to istop (exluded)
    const istart = ithread * pixels_per_thread;

    const istop = blk: {
        if (istart + pixels_per_thread <= num_pixels) {
            break :blk istart + pixels_per_thread;
        } else {
            break :blk num_pixels;
        }
    };

    var prng = std.rand.DefaultPrng.init(ithread);

    log.debug("thread {d} will render [{d}-{d}) (of {d})", .{ ithread, istart, istop, num_pixels });

    try render(.{
        .allocator = ctx.allocator,
        .camera = ctx.camera,
        .img = ctx.img,
        .istart = istart,
        .istop = istop,
        .r = &prng.random(),
        .ray_tracer_config = ctx.cfg,
        .scene = ctx.scene,
        .slice = ctx.slice,
    });

    const t1 = timer.lap();
    const elapsed_s = @intToFloat(f64, t1 - t0) / std.time.ns_per_s;
    log.debug("thread {d} done. It took {d:.2} seconds", .{ ithread, elapsed_s });
}
