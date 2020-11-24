const std = @import("std");
const math = std.math;
const vector = @import("./vector.zig");
const Vec3f = vector.Vec3f;

/// Linear Interpolation
/// Linearly interpolate alongisde a direction.
/// blendedValue = (1−t)⋅startValue + t⋅stopValue
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#rays,asimplecamera,andbackground/sendingraysintothescene
pub fn lerp(direction: Vec3f, start: Vec3f, stop: Vec3f) Vec3f {
    const u = vector.unitVector(direction);
    const t = (u.y + 1.0) * 0.5;
    const a = start.mul(1.0 - t);
    const b = stop.mul(t);
    return a.add(b);
}

pub fn ask_user() !usize {
    const stdin = std.io.getStdIn().inStream();
    const stdout = std.io.getStdOut().outStream();

    var buf: [10]u8 = undefined;

    try stdout.print("Pick a positive integer please: ", .{});

    if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        return std.fmt.parseInt(usize, user_input, 10);
    } else {
        return @as(usize, 0);
    }
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "lerp" {
    const direction = Vec3f.new(3.0, 3.0, 0.0);
    const start = Vec3f.new(1.0, 1.0, 1.0);  // white
    const stop = Vec3f.new(0.5, 0.7, 1.0); // blue
    const v = lerp(direction, start, stop);
    expect(v.x > 0.0 and v.x < 1.0);
    expect(v.y > 0.0 and v.y < 1.0);
}
