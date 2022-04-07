//! This module contains functions to use in the Monte Carlo path tracing algorithm.
//!
//! Reference:
//! - https://www.hxa.name/minilight/
//! - https://www.reddit.com/r/explainlikeimfive/comments/1s38mk/eli5_what_is_the_difference_between_luminance/
//! - [The Physics of Light and Rendering, a talk given by John Carmack at QuakeCon 2013](https://youtu.be/P6UKhR0T6cs)

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const epsilon = @import("./constants.zig").epsilon;
const Material = @import("./material.zig").Material;
const Ray = @import("./ray.zig").Ray;
const RayTracerConfig = @import("./raytracer.zig").RayTracerConfig;
const Scene = @import("./scene.zig").Scene;
const Vec3f = @import("./vec3.zig").Vec3f;

// TODO: double check this linear intepolation formula.

/// Find a point by linearly interpolating from `p0` and `p1`.
/// The caller must provide a unit-length vector for the direction `u`.
/// blendedValue = (1−t)⋅startValue + t⋅stopValue
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#rays,asimplecamera,andbackground/sendingraysintothescene
pub fn lerp(u: Vec3f, p0: Vec3f, p1: Vec3f) error{DirectionIsNotUnitVector}!Vec3f {
    // assert(std.math.fabs(u.length() - 1.0) < epsilon);
    if (std.math.fabs(u.length() - 1.0) > epsilon) {
        return error.DirectionIsNotUnitVector;
    }
    const t = (u.y + 1.0) * 0.5;
    return p0.mul(1.0 - t).add(p1.mul(t));
}

/// Color a pixel based on surface normals.
///
/// If the ray hits an object in the 3D world, color the pixel according to the
/// surface normal passing through the point hit by the ray.
/// If the ray doesn't hit anything, color the pixel using linear interpolation.
/// RGB values are between 0.0 and 1.0.
pub fn colorNormal(ray: Ray, scene: *const Scene, t_min: f32, t_max: f32, blend_start: Vec3f, blend_stop: Vec3f) !Vec3f {
    const maybe_hit = scene.is_hit(ray, t_min, t_max);
    if (maybe_hit) |hit| {
        // const scatter = hit.material.scatter(ray);
        const n = ray.pointAt(hit.t).sub(Vec3f.new(0.0, 0.0, -1.0)).unitVector();
        return n.add(Vec3f.new(1.0, 1.0, 1.0)).mul(0.5);
    } else {
        return try lerp(ray.direction, blend_start, blend_stop);
    }
}

/// Color a pixel based on the albedo (reflected light over incident light).
///
/// If the ray hits an object in the 3D world, color the pixel according to the
/// albedo of the point hit by the ray.
/// If the ray doesn't hit anything, color the pixel using linear interpolation.
/// RGB values are between 0.0 and 1.0.
/// https://www.scratchapixel.com/lessons/3d-basic-rendering/introduction-to-shading/diffuse-lambertian-shading
pub fn colorAlbedo(ray: Ray, scene: *const Scene, t_min: f32, t_max: f32, blend_start: Vec3f, blend_stop: Vec3f) !Vec3f {
    const maybe_hit = scene.is_hit(ray, t_min, t_max);
    if (maybe_hit) |hit| {
        // const n = ray.pointAt(hit.t).sub(Vec3f.new(0.0, 0.0, -1.0)).unitVector();
        // return n.add(Vec3f.one()).mul(0.5);
        return switch (hit.material) {
            Material._lambertian => |mat| mat.albedo,
            Material._metal => |mat| mat.albedo,
            Material._dielectric => |_| Vec3f.new(1.0, 1.0, 1.0),
        };
    } else {
        return try lerp(ray.direction, blend_start, blend_stop);
    }
}

/// Compute the radiance (intensity of light).
pub fn radiance(r: *std.rand.Random, ray: Ray, scene: *const Scene, cfg: *const RayTracerConfig, blend_start: Vec3f, blend_stop: Vec3f, num_rebounds: u32) error{DirectionIsNotUnitVector}!Vec3f {
    const maybe_hit = scene.is_hit(ray, cfg.t_min, cfg.t_max);
    if (maybe_hit) |hit| {
        // If we've exceeded the ray bounce limit, no more light is gathered.
        if (num_rebounds <= 0) {
            return Vec3f.new(0.0, 0.0, 0.0);
        } else {
            const s = Material.scatter(ray, hit, r);
            const v = try radiance(r, s.ray, scene, cfg, blend_start, blend_stop, num_rebounds - 1);
            return v.elementwiseMul(s.attenuation);
        }
    } else {
        return try lerp(ray.direction, blend_start, blend_stop);
    }
}

test "lerp() returns the expected error when unit vector has length > 1" {
    const u = Vec3f.new(1.0, 2.0, 3.0);
    const p0 = Vec3f.new(0.6, 0.0, 0.0);
    const p1 = Vec3f.new(0.2, 0.8, 0.0);

    try expectError(error.DirectionIsNotUnitVector, lerp(u, p0, p1));
}

test "lerp() returns a vector of length >= 1.0 when p0 and p1 are vectors of length >= 0" {
    const alpha = @as(f32, 60.0);
    const u = Vec3f.new(std.math.cos(alpha), std.math.sin(alpha), 0.0); // 60 degrees CCW from origin
    const p0 = Vec3f.new(1.0, 1.0, 0.0);
    const p1 = Vec3f.new(2.0, 2.0, 0.0);

    const v = try lerp(u, p0, p1);

    try expect(u.lengthSquared() <= 1.0);
    try expect(p0.lengthSquared() >= 1.0);
    try expect(p1.lengthSquared() >= 1.0);
    try expect(v.lengthSquared() >= 1.0);
}

test "lerp() write a description for this test" {
    const direction = Vec3f.new(3.0, 4.0, 5.0).unitVector();
    const start = Vec3f.new(1.0, 1.0, 1.0); // white
    const stop = Vec3f.new(0.5, 0.7, 1.0); // blue

    const v = try lerp(direction, start, stop);

    try expect(v.x > 0.0 and v.x < 1.0);
    try expect(v.y > 0.0 and v.y < 1.0);
}
