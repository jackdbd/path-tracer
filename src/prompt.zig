//! Interactive command line utilities.
//! See also: https://github.com/nektro/zig-inquirer
//! - [zig-inquirer](https://github.com/nektro/zig-inquirer)
const std = @import("std");

const Config = struct {
    message: []const u8,
    default: usize,
};

/// Ask the user for an unsigned integer
pub fn askPositiveInteger(cfg: Config) !usize {
    const message = cfg.message;
    const default = cfg.default;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buf: [4]u8 = undefined; // TODO: why 4 elements of u8?
    try stdout.print("{s} (default: {d}): ", .{ message, default });

    if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        const value = std.fmt.parseInt(u32, user_input, 10) catch |err| switch (@TypeOf(err)) {
            std.fmt.ParseIntError => {
                std.log.debug("invalid/missing user input: {s}. Using default: {d}", .{ user_input, default });
                return default;
            },
            else => err,
        };
        return value;
    } else {
        std.log.debug("cannot read user input. Using default: {d}", .{default});
        return @as(usize, 0);
    }
}
