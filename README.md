# Ray Tracing in one weekend in zig

Implementation of Peter Shirley's [Ray Tracing in One Weekend](https://github.com/RayTracing/raytracing.github.io) book in the Zig programming language.

## Dependencies

zig version `0.7.0+39336fd2e`. See [here](https://ziglang.org/download/#release-master).

## Build

Build and run the executable in [debug](https://ziglang.org/documentation/master/#Debug) mode.

```sh
zig build run
```

Build the executable in [release-fast](https://ziglang.org/documentation/master/#toc-ReleaseFast) mode, then run it.

```sh
zig build -Drelease-fast --verbose
# run it
./zig-cache/bin/ray-tracing-in-one-weekend-zig
```

## Other

CLI use, thanks to [zig-clap](https://github.com/Hejsil/zig-clap).

```
./zig-cache/bin/ray-tracing-in-one-weekend-zig 256 -s 20 --spp 100

# render scene 20 in an image 256 pixels wide, use a seed of 123, and run on a single thread
./zig-cache/bin/ray-tracing-in-one-weekend-zig 256 -s 20 --seed 123 --single
```

Format all zig code

```sh
zig fmt src
```

Run all tests

```sh
zig build test
```
