//! This module describes a Portable Pixmap file (.ppm).
//!
//! Reference:
//! - http://netpbm.sourceforge.net/doc/ppm.html
//! - https://fileinfo.com/extension/ppm
//! - https://en.wikipedia.org/wiki/Netpbm

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;

const utils = @import("../utils.zig");
const Vec3f = @import("../vec3.zig").Vec3f;
const colNumToString = utils.colNumToString;
const numDigits = utils.numDigits;

/// Configuration for the .ppm image.
pub const Config = struct {
    aspect_ratio: f32,
    max_px_value: usize,
    width: usize,
};

/// This `struct` represents a .ppm image.
pub const Image = struct {
    // Aspect ratio of the .ppm image.
    aspect_ratio: f32,
    // Start color to control the linear intepolation for the background color.
    blend_start: Vec3f,
    // Stop color to control the linear intepolation for the background color.
    blend_stop: Vec3f,
    // Required memory for all pixel data (in bytes).
    data_size: usize,
    // Required memory size for the .ppm image file header (in bytes).
    // - P3 is the .ppm image "magic number". It's a 2 ASCII characters code,
    //   hence 2 bytes.
    // - width, height and max_px_value can require any number of characters.
    // - the rest of the header size is due to spaces and new lines.
    header_size: usize,
    height: usize,
    // Maximum value for each color in the .ppm image (e.g. 255 for an image
    // that has a color depth of 8-bit; 65535 for an image that has a color
    // depth of 16-bit).
    max_px_value: usize,
    num_pixels: usize,
    // Number of ASCII characters for each RGB pixel in the .ppm image.
    // Example: 255 100 200\n requires 12 characters
    px_size: usize,
    // Required memory for the entire .ppm image (header + data)
    size: usize,
    width: usize,

    const Self = @This();

    /// Creates a new .ppm image.
    pub fn new(cfg: Config) Self {
        const height = @floatToInt(usize, @intToFloat(f32, cfg.width) / cfg.aspect_ratio);
        // 3 channels (RGB) * N characters for the max value (e.g. 255) + spaces and new lines
        const px_size = 3 * numDigits(cfg.max_px_value) + 2 + 1;
        // P3 + characters for the width (e.g. 1280) + characters for the height (e.g. 720) + characters for the max value (e.g. 255) + spaces and new lines
        const header_size = 2 + 1 + numDigits(cfg.width) + 1 + numDigits(height) + 1 + numDigits(cfg.max_px_value) + 1;
        const data_size = px_size * cfg.width * height;

        return Self{
            .aspect_ratio = cfg.aspect_ratio,
            .blend_start = Vec3f.new(1.0, 1.0, 1.0), // white
            .blend_stop = Vec3f.new(0.5, 0.7, 1.0), // blue
            // .blend_stop = Vec3f.new(1.0, 0.27, 0.0), // orange
            .data_size = data_size,
            .header_size = header_size,
            .height = height,
            .max_px_value = cfg.max_px_value,
            .num_pixels = cfg.width * height,
            .px_size = px_size,
            .size = header_size + data_size,
            .width = cfg.width,
        };
    }

    /// Returns the header of the .ppm image. The caller should free the allocated memory.
    pub fn header(self: *const Self, allocator: *std.mem.Allocator) ![]const u8 {
        const slice = try allocator.alloc(u8, self.header_size);
        // P3 means this is a RGB color image in ASCII.
        return try std.fmt.bufPrint(slice, "P3\n{d} {d}\n{d}\n", .{ self.width, self.height, self.max_px_value });
    }

    /// Returns an ASCII representation of a RGB color vector. The caller should free the allocated memory.
    ///
    /// This ASCII string represents the color of a pixel in the .ppm image.
    pub fn rgbToAscii(self: *const Self, allocator: *std.mem.Allocator, col: Vec3f) ![]const u8 {
        const slice = try allocator.alloc(u8, self.px_size);
        const r = try colNumToString(allocator, self.max_px_value, @floatToInt(u8, col.x));
        const g = try colNumToString(allocator, self.max_px_value, @floatToInt(u8, col.y));
        const b = try colNumToString(allocator, self.max_px_value, @floatToInt(u8, col.z));
        defer allocator.free(r);
        defer allocator.free(g);
        defer allocator.free(b);

        return try std.fmt.bufPrint(slice, "{s} {s} {s}\n", .{ r, g, b });
    }
};

test "Image.new() 8-bit image px_size" {
    // 8-bit image (2^8 = 256 color levels)
    const img = Image.new(.{ .width = 640, .aspect_ratio = 16.0 / 9.0, .max_px_value = 255 });

    try expectEqual(@as(usize, 12), img.px_size);
}

test "the size of the header is the expected number of bytes" {
    const img = Image.new(.{ .width = 640, .aspect_ratio = 16.0 / 9.0, .max_px_value = 255 });
    var allocator = std.testing.allocator;

    const header = try img.header(&allocator);
    defer allocator.free(header);
    // std.log.debug("{*}\n", .{header.ptr});

    try expectEqual(@as(usize, 15), header.len);
}

test "the header is the expected string" {
    const img = Image.new(.{ .width = 640, .aspect_ratio = 16.0 / 9.0, .max_px_value = 255 });
    var allocator = std.testing.allocator;

    const header = try img.header(&allocator);
    defer allocator.free(header);
    // std.log.debug("{*}\n", .{header.ptr});

    try expectEqualStrings("P3\n640 360\n255\n", header);
    try expectEqualSlices(u8, &[_]u8{ 'P', '3', '\n', '6', '4', '0', ' ', '3', '6', '0', '\n', '2', '5', '5', '\n' }, header);
}

test "Image.new() 16-bit image px_size" {
    // 16-bit image (2^16 = 65536 color levels)
    const img = Image.new(.{ .width = 640, .aspect_ratio = 16.0 / 9.0, .max_px_value = 65535 });

    try expectEqual(@as(usize, 18), img.px_size);
}

test "rgbToAscii() returns the expected ASCII string" {
    const img = Image.new(.{ .width = 640, .aspect_ratio = 16.0 / 9.0, .max_px_value = 255 });
    const col = Vec3f.new(0.5, 0.7, 1.0); // blue
    // const col = Vec3f.new(1.0, 0.27, 0.0); // orange
    // const col = Vec3f.new(1.0, 0.99, 0.0);
    var allocator = std.testing.allocator;

    const ascii = try img.rgbToAscii(&allocator, col);
    defer allocator.free(ascii);

    try expectEqualStrings("  0   0   1\n", ascii);
}

test "rgbToAscii() write a description for this test" {
    const img = Image.new(.{ .width = 640, .aspect_ratio = 16.0 / 9.0, .max_px_value = 255 });
    var allocator = std.testing.allocator;

    const ascii = try img.rgbToAscii(&allocator, Vec3f.new(255, 10, 0));
    defer allocator.free(ascii);

    try expectEqual(ascii[0], 50); // 2
    try expectEqual(ascii[1], 53); // 5
    try expectEqual(ascii[2], 53); // 5
    try expectEqual(ascii[3], 32); // space
    try expectEqual(ascii[4], 32); // space (leftpad)
    try expectEqual(ascii[5], 49); // 1
    try expectEqual(ascii[6], 48); // 0
    try expectEqual(ascii[7], 32); // space
    try expectEqual(ascii[8], 32); // space (leftpad)
    try expectEqual(ascii[9], 32); // space (leftpad)
    try expectEqual(ascii[10], 48); // 0
    try expectEqual(ascii[11], 10); // \n
}
