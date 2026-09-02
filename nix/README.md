# Building PrusaSlicer 3.0 with Nix

This directory holds a Nix package for the 3.0 development series. The
`flake.nix` in the repository root wires it up so that the checkout itself is
the source; the version is read from `version.inc`.

```sh
# build and run the checkout
nix build
./result/bin/prusa-slicer

# or directly
nix run .

# same build with the Catch2 test suites compiled and executed
nix build .#prusa-slicer-tested

# a shell with every build dependency, for hacking on the C++ code
nix develop
cmake -S . -B build -G Ninja $cmakeFlags
cmake --build build
```

`nix/package.nix` is a regular `callPackage`-style expression. Without a `src`
argument it fetches the upstream release tag, so it can also be used outside of
the flake, for example from an overlay:

```nix
final: prev: {
  prusa-slicer-alpha = final.callPackage /path/to/PrusaSlicer/nix/package.nix { };
}
```

## Options

| argument       | default | meaning                                                        |
|----------------|---------|----------------------------------------------------------------|
| `useClang`     | `true`  | Compile with clang; GCC needs far more memory on this code base |
| `withWebKit`   | `true`  | Embedded browser via WebKitGTK                                  |
| `withStep`     | `true`  | STEP import through OpenCASCADE (`OCCTWrapper.so`)             |
| `allowWayland` | `true`  | Do not force `GDK_BACKEND=x11` (same choice as nixpkgs' 2.9)   |
| `doCheck`      | `false` | Build and run the unit tests                                    |

## How the dependencies map to nixpkgs

Almost everything from `deps/` comes straight from nixpkgs (Boost 1.86,
oneTBB, OpenVDB, CGAL 5, OpenCASCADE 7.6.1, wxWidgets 3.3, Lua 5.4 + sol2,
rapidyaml, magic_enum, range-v3, spdlog, cpptrace, Tracy, ...). The
exceptions live next to this file:

* `libassert.nix` - not in nixpkgs; v2.2.1 against the nixpkgs cpptrace.
* `yoga.nix` - not in nixpkgs; v3.1.0 with `deps/+yoga/yoga.patch` applied.
* `prusa-fdm-mixer.nix` - not in nixpkgs; the `cpp/` part of the upstream
  repository with the CMake files from `deps/+prusa_fdm_mixer`.
* `package.nix` also overrides three nixpkgs packages in place: `nanosvg`
  (the fltk fork that PrusaSlicer requires), `libbgcode` (the revision pinned
  in `deps/+LibBGCode`) and `nlohmann_json` (`deps/+json/json.patch` plus
  implicit conversions disabled, as in the vendored build).

Two small source adjustments are made in `postPatch`: wxWidgets is searched in
module mode because the nixpkgs build ships no CMake package config, and
`libdeflate::libdeflate_shared` is used because nixpkgs does not build the
static library. The STEP plugin is installed to `lib/prusa-slicer/` and its
absolute path is compiled in.
