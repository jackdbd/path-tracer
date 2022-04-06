const std = @import("std");

pub const epsilon: f32 = 0.00001; // or 1e-5
pub const inf = std.math.inf(f32);
pub const negative_inf = -std.math.inf(f64);
pub const nan = std.math.nan(f128);
pub const pi: f32 = 3.1415926535897932385;

// We consider a HitRecord only if t_min < t < t_max
// https://raytracing.github.io/books/RayTracingInOneWeekend.html#surfacenormalsandmultipleobjects/anabstractionforhittableobjects
pub const t_min = 0.0;
pub const t_max = 1000.0;

test "t_min <= t_max" {
    try std.testing.expect(t_min <= t_max);
}
