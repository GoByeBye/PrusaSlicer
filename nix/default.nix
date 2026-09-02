# Non-flake entry point:
#
#   nix-build nix/ -A prusa-slicer
#   nix-build nix/ -A prusa-slicer-deps
#
# or, from an overlay / another expression:
#
#   (import ./nix { inherit pkgs; }).prusa-slicer
{
  pkgs ? import <nixpkgs> { },
}:

let
  src = ../.;

  version =
    let
      m = builtins.match ".*SLIC3R_VERSION \"([^\"]+)\".*" (builtins.readFile ../version.inc);
    in
    if m == null then "unknown" else builtins.head m;

  prusa-slicer-deps = pkgs.callPackage ./prusa-slicer/deps.nix { inherit src version; };

  prusa-slicer = pkgs.callPackage ./prusa-slicer/package.nix {
    inherit src version prusa-slicer-deps;
  };
in
{
  inherit prusa-slicer prusa-slicer-deps;
}
