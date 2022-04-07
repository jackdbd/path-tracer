# Ray Tracing in one weekend in zig

[![CI](https://github.com/jackdbd/path-tracer/actions/workflows/ci.yaml/badge.svg)](https://github.com/jackdbd/path-tracer/actions/workflows/ci.yaml)

Implementation of Peter Shirley's [Ray Tracing in One Weekend](https://github.com/RayTracing/raytracing.github.io) book in the Zig programming language.

Tested on Zig version **0.9.1**.

![scene 21 rendered with 150 samples per pixel, depth 6, seed 456](./images/demo.png)

## Installation

Clone the repo and jump into it:

```sh
git clone git@github.com:jackdbd/path-tracer.git
cd path-tracer
```

In order to use this library and run the examples you will need zig version **0.9.1**. You can get it using [zigup](https://github.com/marler8997/zigup):

```sh
zigup fetch 0.9.1
zigup 0.9.1
```

## Build

Build and run the executable in [debug](https://ziglang.org/documentation/master/#Debug) mode.

```sh
zig build run
```

Build the executable in [release-fast](https://ziglang.org/documentation/master/#ReleaseFast) mode, then run it.

```sh
zig build -Drelease-fast --verbose
# run it
./zig-out/bin/ray-tracing-in-one-weekend-zig
```

## Tests

Run all tests:

```sh
zig build test
```

Otherwise, run all tests defined in a single file:

```sh
zig test src/material.zig
zig test src/utils.zig
zig test src/render_targets/ppm_image.zig --main-pkg-path ./src
```

## Other

Format all zig code

```sh
zig fmt src
```

## TODO

- convert rendered scenes from .ppm => .png and showcase them in the README
- fix multithreading example
- implement example with async/await
- generate docs with `zig test src/utils.zig -femit-docs=./docs` or another command
- fix issues tieh zig-clap and zigmod
