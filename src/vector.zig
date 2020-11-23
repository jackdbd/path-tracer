const std = @import("std");
const math = std.math;
const Random = std.rand.Random;
// const assert = std.debug.assert;

/// A 3 dimensional vector.
pub fn Vec3(comptime T: type) type {
    if (@typeInfo(T) != .Float) {
        @compileError("Vec3 not implemented for " ++ @typeName(T));
    }
    return packed struct {
        x: T,
        y: T,
        z: T,

        const Self = @This();

        // Create a new vector from 3 coordinates.
        pub fn new(x: T, y: T, z: T) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub fn zero() Self {
            return Self.new(0.0, 0.0, 0.0);
        }

        pub fn one() Self {
            return Self.new(1.0, 1.0, 1.0);
        }

        pub fn up() Self {
            return Self.new(0.0, 1.0, 0.0);
        }

        pub fn down() Self {
            return Self.new(0.0, -1.0, 0.0);
        }

        pub fn right() Self {
            return Self.new(1.0, 0.0, 0.0);
        }

        pub fn left() Self {
            return Self.new(-1.0, 0.0, 0.0);
        }

        pub fn back() Self {
            return Self.new(0.0, 0.0, -1.0);
        }

        pub fn forward() Self {
            return Self.new(0.0, 0.0, 1.0);
        }

        /// Compute the length (magnitude) of given vector.
        pub fn length(self: Self) T {
            return math.sqrt(self.lengthSquared());
        }

        /// Addition between two given vectors.
        pub fn add(a: Self, b: Self) Self {
            return Self.new(a.x + b.x, a.y + b.y, a.z + b.z);
        }

        /// Substraction between two given vectors.
        pub fn sub(a: Self, b: Self) Self {
            return Self.new(a.x - b.x, a.y - b.y, a.z - b.z);
        }

        pub fn mul(self: Self, s: T) Self {
            return Self{
                .x = s * self.x,
                .y = s * self.y,
                .z = s * self.z,
            };
        }

        pub fn elementwiseMul(a: Self, b: Self) Self {
            return Self{
                .x = a.x * b.x,
                .y = a.y * b.y,
                .z = a.z * b.z,
            };
        }

        pub fn lengthSquared(self: Self) T {
            return math.pow(T, self.x, 2) + math.pow(T, self.y, 2) + math.pow(T, self.z, 2);
        }

        pub fn randomInUnitSphere(r: *Random) Self {
            return while (true) {
                const p = Vec3f.new(r.float(f32), r.float(f32), r.float(f32));
                if (p.lengthSquared() < 1.0) {
                    break p;
                }
                // WTF, why do we need an else for a while loop? O.o
            } else Vec3f.zero();
        }

        pub fn randomInUnitDisk(r: *Random) Self {
            return while (true) {
                const p = Vec3f.new(2.0 * r.float(f32) - 1.0, 2.0 * r.float(f32) - 1.0, 0.0);
                if (p.lengthSquared() < 1.0) {
                    break p;
                }
            } else Vec3f.zero();
        }

        // utilities for color vectors
        // TODO: create color.zig and move them there?

        pub fn writeColor(self: Self) void {
            std.debug.print("x: {}\n", .{self.x});
        }

        /// leftpad spaces to number, if necessary, so "9" becomes "  9"
        fn color_str(allocator: *std.mem.Allocator, value: u8) ![]const u8 {
            const slice = try allocator.alloc(u8, 3);
            switch (value) {
                0...9 => {
                    return try std.fmt.bufPrint(slice, "  {}", .{value});
                },
                10...99 => {
                    return try std.fmt.bufPrint(slice, " {}", .{value});
                },
                else => {
                    return try std.fmt.bufPrint(slice, "{}", .{value});
                },
            }
        }

        /// Generate an ASCII representation of a RGB color vector.
        /// This ASCII string represents the color of a pixel in a .ppm image.
        pub fn toAsciiLine(self: Self, allocator: *std.mem.Allocator) ![]const u8 {
            // R G B\n --> 255 100 200\n --> 9 u8 for RGB + 2 for spaces + 1 for new line
            const px_mem_size: usize = 3 * 3 + 2 * 1 + 1;
            const slice = try allocator.alloc(u8, px_mem_size);
            const rs = color_str(allocator, @floatToInt(u8, self.x));
            const gs = color_str(allocator, @floatToInt(u8, self.y));
            const bs = color_str(allocator, @floatToInt(u8, self.z));
            return try std.fmt.bufPrint(slice, "{} {} {}\n", .{ rs, gs, bs });
        }
    };
}

pub fn unitVector(v: Vec3(f32)) Vec3(f32) {
    const inv_n = 1.0 / v.length();
    return Vec3(f32).new(inv_n * v.x, inv_n * v.y, inv_n * v.z);
}

pub fn dot(a: Vec3(f32), b: Vec3(f32)) f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

pub fn cross(a: Vec3(f32), b: Vec3(f32)) Vec3(f32) {
    return Vec3(f32).new(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
    );
}

// type aliases
pub const Vec3f = Vec3(f32);
pub const vec3f = Vec3(f32);
pub const Vec3_f64 = Vec3(f64);
pub const vec3_f64 = Vec3(f64);
pub const Point = Vec3(f32);
pub const Color = Vec3(f32);

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const epsilon: f32 = 0.00001; // or 1e-5

test "Vec3f.new" {
    const v = Vec3f.new(1.0, 2.0, 3.0);
    expectEqual(v.x, 1.0);
    expectEqual(v.y, 2.0);
    expectEqual(v.z, 3.0);
}

test "Vec3f.zero" {
    const v = Vec3f.zero();
    expectEqual(v.x, 0.0);
    expectEqual(v.y, 0.0);
    expectEqual(v.z, 0.0);
    const v1 = vec3f.new(0.0, 0.0, 0.0);
    // This does not work. I think I would need operator overloading.
    // expect(v == v1);
    expectEqual(v.x, v1.x);
    expectEqual(v.y, v1.y);
    expectEqual(v.z, v1.z);
}

test "Vec3f.one" {
    const v = Vec3f.one();
    expectEqual(v.x, 1.0);
    expectEqual(v.y, 1.0);
    expectEqual(v.z, 1.0);
    const v1 = vec3f.new(1.0, 1.0, 1.0);
    expectEqual(v.x, v1.x);
    expectEqual(v.y, v1.y);
    expectEqual(v.z, v1.z);
}

test "Vec3f up/down" {
    const up = Vec3f.up();
    const down = Vec3f.down();
    expectEqual(up.y, -down.y);
}

test "Vec3f left/right" {
    const left = Vec3f.left();
    const right = Vec3f.right();
    expectEqual(left.x, -right.x);
}

test "Vec3f back/forward" {
    const back = Vec3f.back();
    const forward = Vec3f.forward();
    expectEqual(back.z, -forward.z);
}

test "Vec3.lengthSquared" {
    const x = 3.0;
    const y = 4.0;
    const z = 5.0;
    const expected = math.pow(f32, x, 2) + math.pow(f32, y, 2) + math.pow(f32, z, 2);
    const v = Vec3f.new(x, y, z);
    expectEqual(v.lengthSquared(), expected);
}

test "Vec3.length" {
    const x = 3.0;
    const y = 4.0;
    const z = 5.0;
    const expected = math.sqrt(math.pow(f32, x, 2) + math.pow(f32, y, 2) + math.pow(f32, z, 2));
    const v = Vec3f.new(x, y, z);
    expectEqual(v.length(), expected);
}

test "Vec3f.add" {
    const a = Vec3f.new(1.0, 2.0, 3.0);
    const b = Vec3f.new(2.0, 3.0, 4.0);
    const v = a.add(b);
    expectEqual(v.x, 3.0);
    expectEqual(v.y, 5.0);
    expectEqual(v.z, 7.0);
}

test "Vec3f.sub" {
    const a = Vec3f.new(2.0, 3.0, 4.0);
    const b = Vec3f.new(2.0, 4.0, 3.0);
    const v = a.sub(b);
    expectEqual(v.x, 0.0);
    expectEqual(v.y, -1.0);
    expectEqual(v.z, 1.0);
}

test "Vec3f.mul" {
    const v = Vec3f.new(2.0, 3.0, 4.0);
    const v1 = v.mul(5.0);
    expectEqual(v1.x, 10.0);
    expectEqual(v1.y, 15.0);
    expectEqual(v1.z, 20.0);
}

test "Vec3f.elementwiseMul" {
    const a = Vec3f.new(2.0, 3.0, 4.0);
    const b = Vec3f.new(3.0, 4.0, 5.0);
    const v = a.elementwiseMul(b);
    expectEqual(v.x, 6.0);
    expectEqual(v.y, 12.0);
    expectEqual(v.z, 20.0);
}

test "dot product" {
    const a = Vec3f.new(2.0, 3.0, 4.0);
    const b = Vec3f.new(5.0, 6.0, 7.0);
    const res = dot(a, b);
    expect(res - 56 < epsilon);
    expectEqual(res, 56);
}

test "unitVector" {
    const v = Vec3f.new(1.0, 2.0, 3.0);
    const uv = unitVector(v);
    expect(math.fabs(uv.length() - 1.0) < epsilon);
}

test "cross product" {
    const a = Vec3f.new(1.0, 0.0, 2.0);
    const b = Vec3f.new(2.0, 1.0, 2.0);
    const v = cross(a, b);
    expectEqual(v.x, -2.0);
    expectEqual(v.y, 2.0);
    expectEqual(v.z, 1.0);
}

test "Color.toAsciiLine" {
    const col = Color.new(255, 10, 0);
    const allocator = std.heap.page_allocator;
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    const ascii = try col.toAsciiLine(&arena_allocator.allocator);
    // std.debug.print("ASCII line\n{}\n", .{ascii});
    defer arena_allocator.deinit();
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
