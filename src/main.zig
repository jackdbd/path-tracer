const std = @import("std");
const vector = @import("./vector.zig");
const vec3f = vector.vec3f;
const Color = vector.Color;
const expect = std.testing.expect;
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

/// Generate a PPM image file of w width and h height, in pixels
fn render_ppm_image(w: usize, h: usize) ![]const u8 {
    log.info("Generating {}x{} .ppm image", .{ w, h });
    log.info("PPM header size: {}", .{header_mem_size});
    log.info("px_mem_size: {}", .{px_mem_size});
    const data_mem_size: usize = px_mem_size * w * h;
    log.info("data_size: {}", .{data_mem_size});
    const total_mem_size: usize = header_mem_size + data_mem_size;
    log.info("total_mem_size: {}", .{total_mem_size});
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

    // This nested loop produces image data in RGB triplets
    var i_px: usize = 0;
    var i_row: usize = 0;
    while (i_row < h) : (i_row += 1) {
        // log.debug("computing row {}/{}...", .{ i_row + 1, h });
        var i_col: usize = 0;
        while (i_col < w) : (i_col += 1) {
            // these RGB values are between 0.0 and 1.0
            const r = @intToFloat(f32, i_col) / @intToFloat(f32, w - 1);
            const g = @intToFloat(f32, i_row) / @intToFloat(f32, h - 1);
            const b = 0.25;

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
    const slice = try render_ppm_image(256, 256);
    const filepath = "images/test-image.ppm";
    try fs.cwd().writeFile(filepath, slice);
    log.info("wrote {}", .{filepath});
}
