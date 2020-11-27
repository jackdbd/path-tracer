const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const Random = std.rand.Random;
const DefaultPrng = std.rand.DefaultPrng;
const Vec3f = @import("vec3.zig").Vec3f;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("sphere.zig").HitRecord;
const epsilon = @import("constants.zig").epsilon;

var prng = DefaultPrng.init(0);

/// Struct that represents how a ray bounces off of a surface, after a hit.
/// ray: the scattered ray
const Scatter = struct {
    attenuation: Vec3f,
    ray: Ray,
};

/// Random vector that falls inside a sphere of radius `r` one.
/// This is useful when generating a random bounce ray for diffuse materials.
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#diffusematerials
fn randomVectorInUnitSphere(r: *Random) Vec3f {
    while (true) {
        const p = Vec3f.new(r.float(f32), r.float(f32), r.float(f32));
        if (p.lengthSquared() < 1.0) {
            return p;
        }
    }
}

/// Struct that represents a diffuse (matte) material.
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#diffusematerials
const Lambertian = struct {
    albedo: Vec3f,

    /// When hitting a lambertian surface, a ray bounces off of the hit point
    /// attenuated, and with a random direction `d`.
    pub fn scatter(self: Lambertian, hit: HitRecord, rand: *Random) Scatter {
        // std.debug.print("\nLambertian scatter: hit: {} rand: {}\n", .{ hit, rand });
        const target = hit.p.add(hit.n.add(randomVectorInUnitSphere(rand)));
        const d = target.sub(hit.p).unitVector();
        return Scatter{
            .attenuation = self.albedo,
            .ray = Ray.new(hit.p, d),
        };
    }
};

/// Reflect an incoming vector `d`, given the surface normal `n`.
/// This function returns the direction for an ideal specular (i.e. mirror) reflection.
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#metal/mirroredlightreflection
/// slide 67 https://drive.google.com/file/d/0B8g97JkuSSBwUENiWTJXeGtTOHFmSm51UC01YWtCZw/view
/// Both `d` and `n` must be unit vectors, because they represent directions.
fn reflect(d: Vec3f, n: Vec3f) Vec3f {
    assert(math.fabs(d.length() - 1.0) < epsilon);
    assert(math.fabs(n.length() - 1.0) < epsilon);
    const r = d.sub(n.mul(2.0 * d.dot(n)));
    assert(math.fabs(r.length() - 1.0) < epsilon);
    return r;
}

/// Struct that represents a metallic material.
/// Metallic materials reflect light, but not exactly like a perfect mirror. Instead,
/// the ray is scattered with some degree of `fuzziness`.
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#metal/fuzzyreflection
const Metal = struct {
    albedo: Vec3f,
    fuzziness: f32,

    /// When hitting a metallic surface, a `ray` bounces off of the hit point
    /// attentuated, and  with a direction `d` given by 2 components:
    /// 1. an ideal specular reflection component `sc`
    /// 2. a fuzzy reflection component `fc`
    pub fn scatter(self: Metal, ray: Ray, hit: HitRecord, rand: *Random) Scatter {
        // std.debug.print("\nMetal scatter: hit: {} rand: {}\n", .{hit, rand});
        const sc = reflect(ray.direction, hit.n);
        const fc = randomVectorInUnitSphere(rand).mul(self.fuzziness);
        const d = sc.add(fc).unitVector();
        return Scatter{
            .attenuation = self.albedo,
            .ray = Ray.new(hit.p, d),
        };
    }
};

/// Refract an incoming vector `d`, given the surface normal `n` and the
/// refraction indices of the 2 media at the interface.
///
/// n1_over_n2: refraction index (aka eta) of the medium for the incident ray,
/// over refraction index (eta prime) for the transmitted (aka refracted) ray.
/// Both `d` and `n` must be unit vectors, because they represent directions.
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#dielectrics/snell'slaw
fn refract(d: Vec3f, n: Vec3f, n1_over_n2: f32) ?Vec3f {
    assert(math.fabs(d.length() - 1.0) < epsilon);
    assert(math.fabs(n.length() - 1.0) < epsilon);
    // const dt = d.dot(n);
    const cos_theta = math.min(d.mul(-1).dot(n), 1.0);
    const r_perpendicular = d.add(n.mul(cos_theta)).mul(n1_over_n2);
    const discriminant = 1.0 - r_perpendicular.lengthSquared();

    if (discriminant < 0) {
        return null;
    }
    const r_parallel = n.mul(-1 * math.sqrt(discriminant));

    // const discriminant = 1.0 - n1_over_n2 * n1_over_n2 * (1.0 - dt * dt);

    const r = r_perpendicular.add(r_parallel);
    assert(math.fabs(r.length() - 1.0) < epsilon);
    return r;
}

/// Schlick's approximation for reflectance.
// https://en.wikipedia.org/wiki/Schlick%27s_approximation
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#dielectrics/schlickapproximation
fn schlick(cosine: f32, refraction_index: f32) f32 {
    var r0 = (1.0 - refraction_index) / (1.0 + refraction_index);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * math.pow(f32, (1.0 - cosine), 5.0);
}

pub const Dielectric = struct {
    refraction_index: f32,

    pub fn scatter(self: Dielectric, ray: Ray, hit: HitRecord, rand: *Random) Scatter {
        var outward_normal: Vec3f = undefined;
        var n1_over_n2: f32 = undefined;
        var cosine: f32 = undefined;

        // Attenuation is always 1 — the glass surface absorbs nothing.
        const attenuation = Vec3f.new(1.0, 1.0, 1.0);

        if (ray.direction.dot(hit.n) > 0.0) {
            outward_normal = Vec3f.new(-hit.n.x, -hit.n.y, -hit.n.z).unitVector();
            n1_over_n2 = self.refraction_index;
            cosine = self.refraction_index * ray.direction.dot(hit.n) / ray.direction.length();
        } else {
            outward_normal = hit.n;
            n1_over_n2 = 1.0 / self.refraction_index;
            cosine = -ray.direction.dot(hit.n) / ray.direction.length();
        }

        if (refract(ray.direction, outward_normal, n1_over_n2)) |refracted_dir| {
            const reflection_prob = schlick(cosine, self.refraction_index);
            // const reflection_prob = 1;
            if (rand.float(f32) < reflection_prob) {
                return Scatter{
                    .attenuation = attenuation,
                    .ray = Ray.new(hit.p, reflect(ray.direction, hit.n)),
                };
            } else {
                return Scatter{
                    .attenuation = attenuation,
                    .ray = Ray.new(hit.p, refracted_dir),
                };
            }
        } else {
            return Scatter{
                .attenuation = attenuation,
                .ray = Ray.new(hit.p, reflect(ray.direction, hit.n)),
            };
        }
    }
};

/// Generic material interface for the objects in the scene.
/// Material is a tagged union so it can delegate the implementation of scatter
/// to Lambertian, Metal, etc.
/// https://ziglang.org/documentation/master/#Tagged-union
pub const Material = union(enum) {
    _lambertian: Lambertian,
    _metal: Metal,
    _dielectric: Dielectric,

    pub fn lambertian(albedo: Vec3f) Material {
        return Material{ ._lambertian = Lambertian{ .albedo = albedo } };
    }

    pub fn metal(albedo: Vec3f, fuzziness: f32) Material {
        return Material{ ._metal = Metal{ .albedo = albedo, .fuzziness = fuzziness } };
    }

    pub fn dielectric(refraction_index: f32) Material {
        return Material{ ._dielectric = Dielectric{ .refraction_index = refraction_index } };
    }

    pub fn scatter(ray: Ray, hit: HitRecord, rand: *Random) Scatter {
        const s = switch (hit.material) {
            Material._lambertian => |mat| mat.scatter(hit, &prng.random),
            Material._metal => |mat| mat.scatter(ray, hit, &prng.random),
            Material._dielectric => |mat| mat.scatter(ray, hit, &prng.random),
        };
        return s;
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Scatter" {
    const attenuation = Vec3f.new(1.0, 2.0, 3.0);
    const ray = Ray.new(Vec3f.new(0.0, 0.0, 0.0), Vec3f.new(1.0, 1.0, 1.0));
    const s = Scatter{ .attenuation = attenuation, .ray = ray };
    expectEqual(s.ray.direction.x, ray.direction.x);
}

// TODO: test for materials

// TODO: test when ray cannot refract and must reflect
// https://raytracing.github.io/books/RayTracingInOneWeekend.html#dielectrics/snell'slaw
test "refract" {
    const d = Vec3f.new(5.0, 2.0, 0.0).unitVector();
    const n = Vec3f.new(-3.0, 2.0, 0.0).unitVector();
    const n1_over_n2 = 0.3;
    const r = refract(d, n, n1_over_n2);
    expect(math.fabs(r.length() - 1.0) < epsilon);
}

// TODO: test for materials
