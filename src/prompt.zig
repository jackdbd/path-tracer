const std = @import("std");

// TODO: improve prompt. Maybe use this library?
// https://github.com/Hejsil/zig-clap
pub fn ask_user() !u32 {
    const stdin = std.io.getStdIn().inStream();
    const stdout = std.io.getStdOut().outStream();
    var buf: [10]u8 = undefined;
    try stdout.print("Pick a positive integer please (e.g. 512): ", .{});

    if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        return std.fmt.parseInt(u32, user_input, 10);
    } else {
        return @as(u32, 0);
    }
}
