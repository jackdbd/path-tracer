const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const Vec3f = @import("vec3.zig").Vec3f;
const epsilon = @import("constants.zig").epsilon;

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

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "utils.lerp" {
    const direction = Vec3f.new(3.0, 4.0, 5.0).unitVector();
    const start = Vec3f.new(1.0, 1.0, 1.0); // white
    const stop = Vec3f.new(0.5, 0.7, 1.0); // blue
    const v = lerp(direction, start, stop);
    expect(v.x > 0.0 and v.x < 1.0);
    expect(v.y > 0.0 and v.y < 1.0);
}
