const std = @import("std");
const vector = @import("./vector.zig");
const Camera = @import("./camera.zig").Camera;
const Ray = @import("./ray.zig").Ray;
const Sphere = @import("./sphere.zig").Sphere;
const utils = @import("./utils.zig");
const Vec3f = vector.Vec3f;
const Color = vector.Color;
const mem = std.mem;
const heap = std.heap;
const fmt = std.fmt;
const fs = std.fs;
const log = std.log;

// P3 is 2 characters, namely 2 bytes. w and h are 3 characters each, 255 is 3
// characters, then there are spaces and new lines.
const header_mem_size: usize = 2 + 1 + 3 + 1 + 3 + 1 + 3 + 1;

fn ppm_header(allocator: *std.mem.Allocator, w: usize, h: usize) ![]const u8 {
    const slice = try allocator.alloc(u8, header_mem_size);
    const header = try fmt.bufPrint(slice, "P3\n{} {}\n255\n", .{ w, h });
    return header;
}

// R G B\n --> 255 100 200\n --> 9 u8 for RGB + 2 for spaces + 1 for new line
const px_mem_size: usize = 3 * 3 + 2 * 1 + 1;

// aspect ratio
const aspect = 16.0 / 9.0;

/// Generate a PPM image file of w width and h height, in pixels
fn render_ppm_image(w: usize, h: usize) ![]const u8 {
    log.info("Generating W:{} x H:{} .ppm image", .{ w, h });
    log.info("PPM header size: {}", .{header_mem_size});
    log.info("px_mem_size: {}", .{px_mem_size});
    const data_mem_size: usize = px_mem_size * w * h;
    log.info("data_size: {}", .{data_mem_size});
    const total_mem_size: usize = header_mem_size + data_mem_size;
    log.info("total_mem_size: {}", .{total_mem_size});

    // TODO: error: unable to evaluate constant expression. How to avoid it?
    // var buffer: [total_mem_size]u8 = undefined;
    var buffer: [786447]u8 = undefined;

    // PPM file header
    // P3 means this is a RGB color image in ASCII
    // 255 is the maximum value for each color

    const allocator = heap.page_allocator;
    var arena_allocator = heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();

    const header = try ppm_header(&arena_allocator.allocator, w, h);
    // log.debug("PPM HEADER\n{}\n", .{header});

    // not sure if u8. The header contains P3, not just numbers
    const slice = try allocator.alloc(u8, total_mem_size);
    mem.copy(u8, slice, header);

    // const count = fmt.count("P3\n{} {}\n255\n", .{ w, h });
    // std.debug.print("fmt.count: {}\n", .{count});

    const vh = 2.0;
    const focal_length = 1.0;
    const camera = Camera.new(Vec3f.zero(), aspect, vh, focal_length);
    // std.debug.print("Camera: {}\n", .{camera});

    // a sphere centered in the viewport (the camera eye is 0,0,0)
    const center = Vec3f.new(0, 0, -1);
    const radius = 0.5;
    const sphere = Sphere.new(center, radius);

    const blend_start = Vec3f.new(1.0, 1.0, 1.0); // white
    const blend_stop = Vec3f.new(0.5, 0.7, 1.0); // blue
    // const blend_stop = Vec3f.new(1.0, 0.27, 0.0); // orange

    // This nested loop produces image data in RGB triplets
    var i_px: usize = 0;
    var i_row: usize = 0;
    while (i_row < h) : (i_row += 1) {
        // log.debug("computing row {}/{}...", .{ i_row + 1, h });
        var i_col: usize = 0;
        while (i_col < w) : (i_col += 1) {
            // these RGB values are between 0.0 and 1.0
            // const r = @intToFloat(f32, i_col) / @intToFloat(f32, w - 1);
            // const g = @intToFloat(f32, i_row) / @intToFloat(f32, h - 1);
            // const b = 0.25;
            const u = @intToFloat(f32, i_col) / @intToFloat(f32, w - 1);
            const v = @intToFloat(f32, h - 1 - i_row) / @intToFloat(f32, h - 1);

            const p = camera.lower_left_corner.add(camera.horizontal.mul(u).add(camera.vertical.mul(v)).sub(camera.origin));
            const ray = Ray.new(camera.origin, p);

            var r: f32 = 0.0;
            var b: f32 = 0.0;
            var g: f32 = 0.0;

            const t = sphere.is_hit(ray);
            if (t > 0.0) {
                const n = vector.unitVector(ray.pointAt(t).sub(Vec3f.new(0.0, 0.0, -1.0)));
                // std.debug.print("Sphere n: {}\n", .{n});
                r = 0.5 * (n.x + 1.0);
                g = 0.5 * (n.y + 1.0);
                b = 0.5 * (n.z + 1.0);
            } else {
                const blended = utils.lerp(p, blend_start, blend_stop);
                r = blended.x;
                g = blended.y;
                b = blended.z;
            }

            const ir = @floatToInt(u8, 255.999 * r);
            // const ir: u8 = 255;
            const ig = @floatToInt(u8, 255.999 * g);
            // const ig: u8 = 100;
            const ib = @floatToInt(u8, 255.999 * b);
            // const ib: u8 = 200;
            // log.debug("[{};{}] R {} G {} B {}", .{i_row, i_col, ir, ig, ib});

            // const px = try rgb_px(&arena_allocator.allocator, ir, ig, ib);
            // std.debug.print("{}", .{px});

            const offset: usize = i_px * px_mem_size;
            // log.debug("i_px {}, offset {}", .{i_px, offset});

            // const ascii_line = try rgb_to_ascii_line(&arena_allocator.allocator, ir, ig, ib);
            const col = Color.new(255.999 * r, 255.999 * g, 255.999 * b);
            // log.debug("Color {}", .{col});
            const ascii_line = try col.toAsciiLine(&arena_allocator.allocator);
            mem.copy(u8, slice[header_mem_size + offset ..], ascii_line);
            i_px += 1;
        }
    }
    return slice;
}

pub fn main() anyerror!void {
    // const w = try utils.ask_user();
    // const h = try utils.ask_user();
    const w = 512;
    // const h = 256;
    const h = @floatToInt(i32, @intToFloat(f32, w) / aspect);
    const slice = try render_ppm_image(w, h);
    const filepath = "images/test-image.ppm";
    try fs.cwd().writeFile(filepath, slice);
    log.info("wrote {}", .{filepath});
}
