# Ray Tracing in one weekend in zig

Implementation of Peter Shirley's [Ray Tracing in One Weekend](https://github.com/RayTracing/raytracing.github.io) book in the Zig programming language.

## Dependencies

zig version `0.7.0+39336fd2e`. See [here](https://ziglang.org/download/#release-master).

## Build

Build the executable in [debug](https://ziglang.org/documentation/master/#Debug) mode.

```sh
zig build run
```

Build the executable in [release-fast](https://ziglang.org/documentation/master/#toc-ReleaseFast) mode.

```sh
zig build run -Drelease-fast
```

## Other

Format all zig code

```sh
zig fmt src
```

Run all tests

```sh
zig build test
```
