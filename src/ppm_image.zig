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
const epsilon = @import("constants.zig").epsilon;
const assert = std.debug.assert;

fn numDigits(num: u32) u8 {
    var x = num;
    var count: u8 = 0;
    while (x != 0) {
        x /= 10;
        count += 1;
    }
    return count;
}

/// maximum value for each color in the .ppm image
pub const max_val = 255;

/// Compute the required memory size for the .ppm image file header.
///
/// P3 is 2 characters, namely 2 bytes. w and h can require any number of
/// characters, 255 is 3 characters, then there are spaces and new lines.
pub fn header_size(w: u32, h: u32) usize {
    const n = numDigits(w);
    return 2 + 1 + numDigits(w) + 1 + numDigits(h) + 1 + numDigits(max_val) + 1;
}

pub fn header(allocator: *mem.Allocator, w: u32, h: u32) ![]const u8 {
    const slice = try allocator.alloc(u8, header_size(w, h));
    // P3 means this is a RGB color image in ASCII.
    return try fmt.bufPrint(slice, "P3\n{} {}\n255\n", .{ w, h });
}

/// Compute the required memory size for each ASCII RGB pixel in the .ppm image.
///
/// Example: 255 100 200\n
pub fn px_size() usize {
    return 3 * numDigits(max_val) + 2 * 1 + 1;
}

pub fn filepath(allocator: *mem.Allocator, num_scene: u8, subsamples: u8, rays_per_subsample: u8, rebounds: u8) ![]const u8 {
    const s = "images/scene-{}--subsamples-{}--rays_per_subsample-{}--rebounds-{}.ppm";
    const n = fmt.count(s, .{ num_scene, subsamples, rays_per_subsample, rebounds });
    const slice = try allocator.alloc(u8, n + numDigits(num_scene) + numDigits(subsamples) + numDigits(rays_per_subsample) + numDigits(rebounds));
    return try fmt.bufPrint(slice, s, .{ num_scene, subsamples, rays_per_subsample, rebounds });
}

/// Convert a color from a numeric value to a padded ASCII string.
fn colNumToString(allocator: *mem.Allocator, value: u8) ![]const u8 {
    const slice = try allocator.alloc(u8, numDigits(max_val));
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

/// Generate an ASCII representation of a RGB color vector.
///
/// This ASCII string represents the color of a pixel in a .ppm image.
pub fn rgbToAscii(allocator: *mem.Allocator, col: Vec3f) ![]const u8 {
    const px_mem_size: usize = 3 * numDigits(max_val) + 2 * 1 + 1;
    const slice = try allocator.alloc(u8, px_mem_size);
    // defer allocator.free(slice);
    const r = try colNumToString(allocator, @floatToInt(u8, col.x));
    const g = try colNumToString(allocator, @floatToInt(u8, col.y));
    const b = try colNumToString(allocator, @floatToInt(u8, col.z));
    // defer allocator.free(r);
    // defer allocator.free(g);
    // defer allocator.free(b);
    return try fmt.bufPrint(slice, "{} {} {}\n", .{ r, g, b });
}

pub fn render(allocator: *mem.Allocator, r: *Random, scene: *Scene, camera: *Camera, cfg: RayTracerConfig, width: u32, height: u32) ![]const u8 {
    log.debug("render loop: render W:{} x H:{} .ppm image", .{ width, height });
    const header_mem_size = header_size(width, height);
    log.debug("PPM header memory size: {}", .{header_mem_size});
    const px_mem_size = px_size();
    log.debug("ASCII RGB pixel memory size: {}", .{px_mem_size});
    const data_mem_size: usize = px_mem_size * width * height;
    log.debug("Data size (i.e. all pixels in .ppm image): {}", .{data_mem_size});
    const total_mem_size: usize = header_mem_size + data_mem_size;
    log.debug("Total memory size for .ppm image: {}", .{total_mem_size});

    const ppm_header = try header(allocator, width, height);
    const slice = try allocator.alloc(u8, total_mem_size);
    mem.copy(u8, slice, ppm_header);

    const blend_start = Vec3f.new(1.0, 1.0, 1.0); // white
    const blend_stop = Vec3f.new(0.5, 0.7, 1.0); // blue
    // const blend_stop = Vec3f.new(1.0, 0.27, 0.0); // orange

    // This nested loop produces image data in RGB triplets.
    var idx: u32 = 0;
    const end_idx = width * height;
    var progress = std.Progress{};
    const root_node = try progress.start("Render loop", end_idx + 1);
    while (idx < end_idx) : (idx += 1) {
        const i_col = @mod(idx, width);
        const i_row = @divTrunc(idx, width);
        // log.debug("idx:{} i_row:{} i_col:{}", .{idx, i_row, i_col});

        var sample: @TypeOf(cfg.subpixels) = 0;
        var color_accum = Vec3f.new(0.0, 0.0, 0.0);
        while (sample < cfg.subpixels) : (sample += 1) {
            var rps: @TypeOf(cfg.rays_per_subsample) = 0;
            while (rps < cfg.rays_per_subsample) : (rps += 1) {
                // TODO: double-check the theory of u, v and the indices
                const u = (@intToFloat(f32, i_col) + r.float(f32)) / @intToFloat(f32, width);
                const v = (@intToFloat(f32, height - i_row + 1) + r.float(f32)) / @intToFloat(f32, height);
                const ray = camera.castRay(u, v, r);
                // const color_sample = colorNormal(ray, scene, cfg.t_min, cfg.t_max, blend_start, blend_stop);
                // const color_sample = colorAlbedo(ray, scene, cfg.t_min, cfg.t_max, blend_start, blend_stop);
                const color_sample = radiance(r, ray, scene, cfg, blend_start, blend_stop, cfg.rebounds);
                color_accum = color_accum.add(color_sample);
            }
        }
        color_accum = color_accum.mul(1.0 / @intToFloat(f32, cfg.subpixels)).mul(1.0 / @intToFloat(f32, cfg.rays_per_subsample));
        // color_accum = color_accum.unitVector();
        // const col = color_accum.mul(255.99);
        const col = color_accum.mul(max_val);
        // log.debug("RGB {} {} {} color_accum: {}", .{col.x, col.y, col.z, color_accum});

        assert(col.x <= max_val and col.y <= max_val and col.z <= max_val);

        const offset: usize = idx * px_mem_size;
        const ascii = try rgbToAscii(allocator, col);
        mem.copy(u8, slice[header_mem_size + offset ..], ascii);

        root_node.completeOne();
    }
    root_node.end();
    return slice;
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
fn radiance(r: *Random, ray: Ray, scene: *const Scene, cfg: RayTracerConfig, blend_start: Vec3f, blend_stop: Vec3f, num_rebounds: u32) Vec3f {
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
