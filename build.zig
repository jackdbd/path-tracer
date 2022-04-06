const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("ray-tracing-in-one-weekend-zig", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    var camera_tests = b.addTest("src/camera.zig");
    var material_tests = b.addTest("src/material.zig");
    var multithreading_tests = b.addTest("src/multithreading.zig");
    var ppm_image_tests = b.addTest("src/ppm_image.zig");
    var ray_tests = b.addTest("src/ray.zig");
    var scene_tests = b.addTest("src/scene.zig");
    var sphere_tests = b.addTest("src/sphere.zig");
    var utils_tests = b.addTest("src/utils.zig");
    var vec3_tests = b.addTest("src/vec3.zig");
    
    camera_tests.setBuildMode(mode);
    material_tests.setBuildMode(mode);
    multithreading_tests.setBuildMode(mode);
    ppm_image_tests.setBuildMode(mode);
    ray_tests.setBuildMode(mode);
    scene_tests.setBuildMode(mode);
    sphere_tests.setBuildMode(mode);
    utils_tests.setBuildMode(mode);
    vec3_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&camera_tests.step);
    test_step.dependOn(&material_tests.step);
    test_step.dependOn(&multithreading_tests.step);
    test_step.dependOn(&ppm_image_tests.step);
    test_step.dependOn(&ray_tests.step);
    test_step.dependOn(&scene_tests.step);
    test_step.dependOn(&sphere_tests.step);
    test_step.dependOn(&utils_tests.step);
    test_step.dependOn(&vec3_tests.step);
}
