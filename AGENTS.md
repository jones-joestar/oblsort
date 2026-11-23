# Repository Guidelines

## Project Structure & Module Organization

- `osort/` contains the C++ library: shared utilities and tracing in `common/`, and external-memory containers, servers, and algorithms in `external_memory/`.
- `tests/` contains GoogleTest correctness and performance tests. `applications/sorting/` contains the Intel SGX example and benchmark runner.
- `cmake/` holds build helpers; `tools/docker/cppbuilder/` provides a reproducible build environment. Benchmark results are written to `benchmark_output/`.

## Build, Test, and Development Commands

Install CMake, Ninja, OpenSSL, Boost, and the Intel SGX SDK as needed; CMake fetches GoogleTest during configuration.

- `cmake -B build -G Ninja` configures the project; add `-DCMAKE_BUILD_TYPE=Release` for an optimized build.
- `ninja -C build` builds the library and test executables.
- `ninja -C build test` runs the tests registered with CTest. Use `ctest --test-dir build --output-on-failure` for failure details.
- In `applications/sorting/`, run `make SGX_MODE=SIM` to build the simulation enclave. Source the SGX SDK environment first; clean before switching SGX build modes.

## Benchmarking

Run benchmarks in the Docker environment. Build the image with `docker build -t cppbuilder:latest ./tools/docker/cppbuilder`, then start it from the repository root:

```bash
docker run -v /tmp/sortbackend:/ssdmount --privileged -it --rm -v "$PWD:/builder" cppbuilder
```

Inside the container, run `cd applications/sorting && ./algo_runner.sh`. The runner defaults to SGX hardware mode; set `SGX_MODE=SIM` for simulation. Results are saved to `benchmark_output/`; the first run is a warm-up.

## Coding Style & Naming Conventions

Follow the surrounding C++ style: two-space indentation, `.hpp` headers, `.cpp` implementations, and descriptive names. The `clangformat` CMake target applies LLVM-style formatting to project sources (`ninja -C build clangformat`); review its changes before committing. Run `ninja -C build cppcheck` for static analysis when cppcheck is installed.

## Commit & Pull Request Guidelines

Do not commit or stage anything unless specifically asked to do so.
