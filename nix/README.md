# Building PrusaSlicer with Nix

This directory packages the PrusaSlicer 3.0 alpha from this source tree.
There are two derivations:

| Attribute            | What it builds                                                                                                 |
| -------------------- | -------------------------------------------------------------------------------------------------------------- |
| `prusa-slicer-deps`  | The `deps/` superproject: every third-party library, statically linked, at the exact versions upstream pins.   |
| `prusa-slicer`       | PrusaSlicer itself, linked against `prusa-slicer-deps`, installed FHS-style with a desktop entry and icons.    |

The dependency bundle is built the same way upstream builds it (`deps/CMakeLists.txt`
driving CMake's ExternalProject) rather than from nixpkgs libraries. The alpha
pins several forks and commits (wxWidgets, libbgcode, prusa-fdm-mixer, OCCT 7.6.1,
...) that nixpkgs does not carry, and the application only supports the static
bundle on Linux. Because the sandbox has no network, every archive is fetched by
Nix first and placed where ExternalProject expects it.

## Usage

With flakes:

```sh
nix build .#prusa-slicer          # or just `nix build`
./result/bin/prusa-slicer
nix run .                         # run without installing
nix develop                       # shell with $PRUSASLICER_DEPS for manual builds
```

Without flakes:

```sh
nix-build nix/ -A prusa-slicer
```

As an overlay in a NixOS or home-manager configuration:

```nix
{
  inputs.prusa-slicer-alpha.url = "github:GoByeBye/PrusaSlicer";
  # ...
  nixpkgs.overlays = [ inputs.prusa-slicer-alpha.overlays.default ];
  environment.systemPackages = [ pkgs.prusa-slicer-alpha ];
}
```

The first build compiles Boost, wxWidgets, OpenCASCADE, OpenVDB, z3, TBB and
about forty other libraries; expect it to take an hour or more and several GB of
RAM. The bundle only rebuilds when `deps/` or `cmake/` changes; the application
rebuilds on any other source change.

## Options

`package.nix` accepts a few overrides:

```nix
prusa-slicer-alpha.override {
  withStep = false;    # drop OpenCASCADE / STEP import
  withWebkit = false;  # drop the embedded WebKitGTK browser
  withTests = true;    # build and run the Catch2 test suite
}
```

## Updating

Whenever a recipe in `deps/+*/` changes its `URL` or `URL_HASH`, regenerate the
source list and commit the result:

```sh
python3 nix/update-deps-sources.py
```

The package version is read from `version.inc`, so version bumps need no edits here.
