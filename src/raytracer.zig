//! Configuration for the ray tracer.
///
/// subpixels: number of subpixels to collect. This supersampling is done for
/// antialiasing. A value of 1 means no antialiasing..
/// Tipically for each pixel a 2x2 subpixel grid is considered, so
/// instead of 1 pixel sample we gather 4 subpixel samples.
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#antialiasing
///
/// t_min, t_max: we consider a HitRecord only if t_min < t < t_max.
///
/// rebounds: number of times each ray can scatter. Even a reasonably low
/// number (e.g. 6) seems to be ok, since after a few rebounds the contribute to
/// the radiance would be negligible anyway.
///
/// rays_per_subsample: number of rays casted for each pixel subsample.
/// https://www.kevinbeason.com/smallpt/
pub const RayTracerConfig = struct {
    subpixels: u8,
    t_min: f32,
    t_max: f32,
    rebounds: u8,
    rays_per_subsample: u8,
};
