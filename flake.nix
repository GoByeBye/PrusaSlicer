{
  description = "PrusaSlicer 3.0 alpha";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      # Taken from version.inc so the package version follows the tree.
      version =
        let
          m = builtins.match ".*SLIC3R_VERSION \"([^\"]+)\".*" (builtins.readFile ./version.inc);
        in
        if m == null then "unknown" else builtins.head m;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      overlays.default = final: prev: {
        prusa-slicer-alpha-deps = final.callPackage ./nix/prusa-slicer/deps.nix {
          src = ./.;
          inherit version;
        };
        prusa-slicer-alpha = final.callPackage ./nix/prusa-slicer/package.nix {
          src = ./.;
          inherit version;
          prusa-slicer-deps = final.prusa-slicer-alpha-deps;
        };
      };

      packages = forAllSystems (
        pkgs:
        let
          p = pkgs.extend self.overlays.default;
        in
        {
          default = p.prusa-slicer-alpha;
          prusa-slicer = p.prusa-slicer-alpha;
          prusa-slicer-deps = p.prusa-slicer-alpha-deps;
        }
      );

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      });

      # Tools for building by hand (doc/Build.md) with the Nix-built dependency
      # bundle: cmake .. -DCMAKE_PREFIX_PATH=$PRUSASLICER_DEPS -DSLIC3R_STATIC=ON
      devShells = forAllSystems (
        pkgs:
        let
          app = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ app ];
            packages = [
              pkgs.ninja
              pkgs.gdb
            ];
            PRUSASLICER_DEPS = self.packages.${pkgs.stdenv.hostPlatform.system}.prusa-slicer-deps;
          };
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
