//! Renderer and utilities for .ppm files.

const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const math = std.math;
const mem = std.mem;
const Random = std.rand.Random;
const Vec3f = @import("vec3.zig").Vec3f;
const Scene = @import("scene.zig").Scene;
const Ray = @import("ray.zig").Ray;
const Camera = @import("camera.zig").Camera;
const Material = @import("material.zig").Material;
const RayTracerConfig = @import("raytracer.zig").RayTracerConfig;
const ThreadContext = @import("multithreading.zig").ThreadContext;
const epsilon = @import("constants.zig").epsilon;
const numDigits = @import("utils.zig").numDigits;
const assert = std.debug.assert;

/// Convert a color from a numeric value to a padded ASCII string.
fn colNumToString(allocator: *mem.Allocator, max_value: u32, value: u8) ![]const u8 {
    const slice = try allocator.alloc(u8, numDigits(max_value));
    // TODO: adopt generic leftpad algorithm, to pad any number of spaces.
    switch (value) {
        0...9 => {
            return try fmt.bufPrint(slice, "  {}", .{value});
        },
        10...99 => {
            return try fmt.bufPrint(slice, " {}", .{value});
        },
        else => {
            return try fmt.bufPrint(slice, "{}", .{value});
        },
    }
}

pub fn render(allocator: *mem.Allocator, slice: []u8, r: *Random, scene: *Scene, camera: *Camera, cfg: *const RayTracerConfig, img: *const Image, istart: u32, istop: u32) !void {
    // log.debug("render pixels [{}-{})", .{ istart, istop });
    var idx: u32 = istart;
    // var progress = std.Progress{};
    // const root_node = try progress.start("Render loop", istop + 1);
    while (idx < istop) : (idx += 1) {
        const i_col = @mod(idx, img.width);
        const i_row = @divTrunc(idx, img.width);
        // log.debug("idx:{} i_row:{} i_col:{}", .{idx, i_row, i_col});

        var sample: @TypeOf(cfg.subpixels) = 0;
        var color_accum = Vec3f.new(0.0, 0.0, 0.0);
        while (sample < cfg.subpixels) : (sample += 1) {
            var rps: @TypeOf(cfg.rays_per_subsample) = 0;
            while (rps < cfg.rays_per_subsample) : (rps += 1) {
                // TODO: double-check the theory of u, v and the indices
                const u = (@intToFloat(f32, i_col) + r.float(f32)) / @intToFloat(f32, img.width);
                const v = (@intToFloat(f32, img.height - i_row + 1) + r.float(f32)) / @intToFloat(f32, img.height);
                const ray = camera.castRay(u, v, r);
                // const color_sample = colorNormal(ray, scene, cfg.t_min, cfg.t_max, img.blend_start, img.blend_stop);
                // const color_sample = colorAlbedo(ray, scene, cfg.t_min, cfg.t_max, img.blend_start, img.blend_stop);
                const color_sample = radiance(r, ray, scene, cfg, img.blend_start, img.blend_stop, cfg.rebounds);
                color_accum = color_accum.add(color_sample);
            }
        }
        color_accum = color_accum.mul(1.0 / @intToFloat(f32, cfg.subpixels)).mul(1.0 / @intToFloat(f32, cfg.rays_per_subsample));
        // color_accum = color_accum.unitVector();
        // const col = color_accum.mul(255.99);
        const max_val_f = @intToFloat(f32, img.max_px_value);
        const col = color_accum.mul(max_val_f);

        assert(col.x <= max_val_f and col.y <= max_val_f and col.z <= max_val_f);

        const offset: usize = idx * img.px_size;
        const ascii = try img.rgbToAscii(allocator, col);
        mem.copy(u8, slice[img.header_size + offset ..], ascii);

        // root_node.completeOne();
    }
    // root_node.end();
}

pub fn renderMultiThread(ctx: ThreadContext) !void {
    // This thread processes pixels from istart (included) to istop (exluded)
    const istart = ctx.ithread * ctx.pixels_per_thread;
    const istop = blk: {
        if (istart + ctx.pixels_per_thread <= ctx.img.num_pixels) {
            break :blk istart + ctx.pixels_per_thread;
        } else {
            break :blk ctx.img.num_pixels;
        }
    };

    // Initialize a random generator with the same seed, for reproducibility.
    var prng = std.rand.DefaultPrng.init(ctx.ithread);
    log.debug("Thread {} will render pixels [{}-{})", .{ ctx.ithread, istart, istop });
    try render(ctx.allocator, ctx.slice, &prng.random, ctx.scene, ctx.camera, ctx.cfg, ctx.img, istart, istop);
    log.info("renderMultiThread thread {} DONE", .{ctx.ithread});
}

/// Color a pixel based on surface normals.
///
/// If the ray hits an object in the 3D world, color the pixel according to the
/// surface normal passing through the point hit by the ray.
/// If the ray doesn't hit anything, color the pixel using linear interpolation.
/// RGB values are between 0.0 and 1.0.
fn colorNormal(ray: Ray, scene: *const Scene, t_min: f32, t_max: f32, blend_start: Vec3f, blend_stop: Vec3f) Vec3f {
    const maybe_hit = scene.is_hit(ray, t_min, t_max);
    if (maybe_hit) |hit| {
        // const scatter = hit.material.scatter(ray);
        const n = ray.pointAt(hit.t).sub(Vec3f.new(0.0, 0.0, -1.0)).unitVector();
        return n.add(Vec3f.new(1.0, 1.0, 1.0)).mul(0.5);
    } else {
        return lerp(ray.direction, blend_start, blend_stop);
    }
}

/// Compute the radiance (intensity of light).
fn radiance(r: *Random, ray: Ray, scene: *const Scene, cfg: *const RayTracerConfig, blend_start: Vec3f, blend_stop: Vec3f, num_rebounds: u32) Vec3f {
    const maybe_hit = scene.is_hit(ray, cfg.t_min, cfg.t_max);
    if (maybe_hit) |hit| {
        // If we've exceeded the ray bounce limit, no more light is gathered.
        if (num_rebounds <= 0) {
            return Vec3f.new(0.0, 0.0, 0.0);
        } else {
            const s = Material.scatter(ray, hit, r);
            return radiance(r, s.ray, scene, cfg, blend_start, blend_stop, num_rebounds - 1).elementwiseMul(s.attenuation);
        }
    } else {
        return lerp(ray.direction, blend_start, blend_stop);
    }
}

/// Color a pixel based on the albedo (reflected light over incident light).
///
/// If the ray hits an object in the 3D world, color the pixel according to the
/// albedo of the point hit by the ray.
/// If the ray doesn't hit anything, color the pixel using linear interpolation.
/// RGB values are between 0.0 and 1.0.
/// https://www.scratchapixel.com/lessons/3d-basic-rendering/introduction-to-shading/diffuse-lambertian-shading
fn colorAlbedo(ray: Ray, scene: *const Scene, t_min: f32, t_max: f32, blend_start: Vec3f, blend_stop: Vec3f) Vec3f {
    const maybe_hit = scene.is_hit(ray, t_min, t_max);
    if (maybe_hit) |hit| {
        // const n = ray.pointAt(hit.t).sub(Vec3f.new(0.0, 0.0, -1.0)).unitVector();
        // return n.add(Vec3f.one()).mul(0.5);
        return switch (hit.material) {
            Material._lambertian => |mat| mat.albedo,
            Material._metal => |mat| mat.albedo,
            Material._dielectric => |_| Vec3f.new(1.0, 1.0, 1.0),
        };
    } else {
        return lerp(ray.direction, blend_start, blend_stop);
    }
}

/// Struct that represents a .ppm image.
pub const Image = struct {
    aspect_ratio: f32,
    // start and stop color to control the linear intepolation for the background color.
    blend_start: Vec3f,
    blend_stop: Vec3f,
    // Required memory for all pixel data
    data_size: usize,
    // Required memory size for the .ppm image file header.
    // P3 is 2 characters, hence 2 bytes. width, height and max_px_value can
    // require any number of characters, then there are spaces and new lines.
    header_size: usize,
    height: u32,
    // Maximum value for each color in the .ppm image (e.g. 255)
    max_px_value: u32,
    num_pixels: u32,
    // Required memory for each ASCII RGB pixel in the .ppm image.
    // Example: 255 100 200\n requires 12 units
    px_size: usize,
    // Required memory for the entire .ppm image (header + data)
    size: usize,
    width: u32,

    const Self = @This();

    pub fn new(width: u32, aspect_ratio: f32, max_px_value: u32) Self {
        const height = @floatToInt(u32, @intToFloat(f32, width) / aspect_ratio);
        const px_size = 3 * numDigits(max_px_value) + 2 * 1 + 1;
        const header_size = 2 + 1 + numDigits(width) + 1 + numDigits(height) + 1 + numDigits(max_px_value) + 1;
        const data_size = px_size * width * height;

        return Self{
            .aspect_ratio = aspect_ratio,
            .blend_start = Vec3f.new(1.0, 1.0, 1.0), // white
            .blend_stop = Vec3f.new(0.5, 0.7, 1.0), // blue
            // .blend_stop = Vec3f.new(1.0, 0.27, 0.0), // orange
            .data_size = data_size,
            .header_size = header_size,
            .height = height,
            .max_px_value = max_px_value,
            .num_pixels = width * height,
            .px_size = px_size,
            .size = header_size + data_size,
            .width = width,
        };
    }

    pub fn header(self: *const Self, allocator: *mem.Allocator) ![]const u8 {
        const slice = try allocator.alloc(u8, self.header_size);
        // P3 means this is a RGB color image in ASCII.
        return try fmt.bufPrint(slice, "P3\n{} {}\n{}\n", .{ self.width, self.height, self.max_px_value });
    }

    /// Generate an ASCII representation of a RGB color vector.
    ///
    /// This ASCII string represents the color of a pixel in the .ppm image.
    pub fn rgbToAscii(self: *const Self, allocator: *mem.Allocator, col: Vec3f) ![]const u8 {
        const slice = try allocator.alloc(u8, self.px_size);
        // defer allocator.free(slice);
        const r = try colNumToString(allocator, self.max_px_value, @floatToInt(u8, col.x));
        const g = try colNumToString(allocator, self.max_px_value, @floatToInt(u8, col.y));
        const b = try colNumToString(allocator, self.max_px_value, @floatToInt(u8, col.z));
        // defer allocator.free(r);
        // defer allocator.free(g);
        // defer allocator.free(b);
        return try fmt.bufPrint(slice, "{} {} {}\n", .{ r, g, b });
    }
};

// TODO: double check this linear intepolation formula.
/// Find a point by linearly interpolating from `p0` and `p1`.
/// The caller must provide a unit-length vector for the direction `u`.
/// blendedValue = (1−t)⋅startValue + t⋅stopValue
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#rays,asimplecamera,andbackground/sendingraysintothescene
pub fn lerp(u: Vec3f, p0: Vec3f, p1: Vec3f) Vec3f {
    assert(math.fabs(u.length() - 1.0) < epsilon);
    const t = (u.y + 1.0) * 0.5;
    return p0.mul(1.0 - t).add(p1.mul(t));
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "ppm_image.colNumToString" {
    const allocator = std.testing.allocator;
    var s = try colNumToString(allocator, @as(u8, 255));
    defer allocator.free(s);
    // std.debug.print("colNumToString: {}\n", .{s});
    // TODO: how to check s?
    // expectEqual("255", &s);
}

// TODO: this test leaks memory. Is the memory leak it in tgbToAscii?
test "ppm_image.rgbToAscii" {
    // const allocator = std.testing.page_allocator;
    // var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    const allocator = std.testing.allocator;
    const ascii = try rgbToAscii(allocator, Vec3f.new(255, 10, 0));
    // defer arena_allocator.deinit();
    // defer allocator.free(ascii);
    // std.debug.print("ASCII line\n{}\n", .{ascii});
    expectEqual(ascii[0], 50); // 2
    expectEqual(ascii[1], 53); // 5
    expectEqual(ascii[2], 53); // 5
    expectEqual(ascii[3], 32); // space
    expectEqual(ascii[4], 32); // space (leftpad)
    expectEqual(ascii[5], 49); // 1
    expectEqual(ascii[6], 48); // 0
    expectEqual(ascii[7], 32); // space
    expectEqual(ascii[8], 32); // space (leftpad)
    expectEqual(ascii[9], 32); // space (leftpad)
    expectEqual(ascii[10], 48); // 0
    expectEqual(ascii[11], 10); // \n
}

test "lerp" {
    const direction = Vec3f.new(3.0, 4.0, 5.0).unitVector();
    const start = Vec3f.new(1.0, 1.0, 1.0); // white
    const stop = Vec3f.new(0.5, 0.7, 1.0); // blue
    const v = lerp(direction, start, stop);
    expect(v.x > 0.0 and v.x < 1.0);
    expect(v.y > 0.0 and v.y < 1.0);
}
