//! Utilities for .ppm files.

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Vec3f = @import("vec3.zig").Vec3f;

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
const max_val = 255;

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

pub fn filepath(allocator: *mem.Allocator, num_samples: u8, depth_max: u8) ![]const u8 {
    const s = "images/image_{}-samples_{}-max-depth.ppm";
    const n = fmt.count(s, .{ num_samples, depth_max });
    const slice = try allocator.alloc(u8, n + numDigits(num_samples) + numDigits(depth_max));
    return try fmt.bufPrint(slice, s, .{ num_samples, depth_max });
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
