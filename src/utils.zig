//! Miscellaneous utilities.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;
const expectStringEndsWith = std.testing.expectStringEndsWith;

/// Counts the digits of the number `num`.
pub fn numDigits(num: usize) u8 {
    var x = num;
    var count: u8 = 0;
    while (x != 0) {
        x /= 10;
        count += 1;
    }
    return count;
}

test "utils.numDigits returns the expected number of digits" {
    const expected: u8 = 3;
    try expectEqual(expected, numDigits(123));
}

/// Converts a character into its ASCII code point.
fn charToDigit(c: u8) u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => std.math.maxInt(u8),
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

/// Converts a 8-bit color `value` into a left-padded ASCII string.
pub fn colNumToString(allocator: *std.mem.Allocator, max_value: usize, value: u8) ![]const u8 {
    if (value > max_value) {
        return error.ValueExceedsMaxValue;
    }
    assert(value <= max_value);
    const slice = try allocator.alloc(u8, numDigits(max_value));
    // TODO: adopt generic leftpad algorithm, to pad any number of spaces.
    // https://gist.github.com/shritesh/1f6f4b6843e72df3aaa880a1ff786b93
    switch (value) {
        0...9 => {
            assert(value <= 9);
            return try std.fmt.bufPrint(slice, "  {d}", .{value});
        },
        10...99 => {
            assert(value <= 99);
            return try std.fmt.bufPrint(slice, " {d}", .{value});
        },
        else => {
            assert(value >= 100);
            return try std.fmt.bufPrint(slice, "{d}", .{value});
        },
    }
}

test "utils.colNumToString returns expected error when value > value_max" {
    var allocator = std.testing.allocator;
    const value = 129;
    const max_value = 128;
    try expectError(error.ValueExceedsMaxValue, colNumToString(&allocator, max_value, value));
}

test "utils.colNumToString returns the expected string" {
    var allocator = std.testing.allocator;
    const value = 42;
    const max_value = 255;
    const actual = try colNumToString(&allocator, max_value, value);
    defer allocator.free(actual);
    const expected: []const u8 = " 42";
    try expectEqualStrings(expected, actual);
}

test "utils.colNumToString returns a string that ends with the expected string" {
    var allocator = std.testing.allocator;
    const value = 42;
    const max_value = 255;
    const actual = try colNumToString(&allocator, max_value, value);
    defer allocator.free(actual);
    const expected_ends_with: []const u8 = "42";
    try expectStringEndsWith(actual, expected_ends_with);
}

pub fn degreesToRadians(deg: f32) f32 {
    return deg * std.math.pi / 180.0;
}
