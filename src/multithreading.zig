const std = @import("std");
const mem = std.mem;

const assert = std.debug.assert;
const expect = std.testing.expect;

const Image = @import("./render_targets/ppm_image.zig").Image;
const Camera = @import("./camera.zig").Camera;
const Scene = @import("./scene.zig").Scene;
const RayTracerConfig = @import("./raytracer.zig").RayTracerConfig;

pub const ThreadContext = struct {
    allocator: *mem.Allocator,
    camera: *Camera,
    cfg: *const RayTracerConfig,
    img: *const Image,
    ithread: u8,
    num_scene: u8,
    pixels_per_thread: usize,
    scene: *Scene,
    slice: []u8,

    const Self = @This();

    pub fn new(allocator: *mem.Allocator, slice: []u8, ithread: u8, scene: *Scene, num_scene: u8, camera: *Camera, cfg: *const RayTracerConfig, img: *const Image, pixels_per_thread: usize) Self {
        return Self{
            .allocator = allocator,
            .camera = camera,
            .cfg = cfg,
            .img = img,
            .ithread = ithread,
            .num_scene = num_scene,
            .pixels_per_thread = pixels_per_thread,
            .scene = scene,
            .slice = slice,
        };
    }
};

pub fn chunkSize(num_pixels: usize, num_threads: usize) usize {
    const n = num_pixels / num_threads;
    const rem = num_pixels % num_threads;
    return if (rem > 0) n + 1 else n;
}

test "multithreading.chunkSize()" {
    const num_pixels = @as(usize, 640 * 480);
    const num_threads = @as(usize, 4);
    try expect(chunkSize(num_pixels, num_threads) < num_pixels);
    try expect(chunkSize(num_pixels, num_threads) > num_threads);
}
