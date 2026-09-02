{
  description = "PrusaSlicer 3.0 (alpha) - G-code generator for 3D printers";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f (pkgsFor system));

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

      # Read SLIC3R_VERSION from version.inc so the package version follows
      # the checkout being built.
      version =
        let
          inc = builtins.readFile "${self}/version.inc";
          line = lib.findFirst (l: lib.hasPrefix "set(SLIC3R_VERSION " l) null (lib.splitString "\n" inc);
          m = if line == null then null else builtins.match "set\\(SLIC3R_VERSION \"([^\"]+)\"\\).*" line;
        in
        if m == null then "0-unknown" else builtins.head m;
    in
    {
      overlays.default = final: prev: {
        prusa-slicer-alpha = final.callPackage ./nix/package.nix {
          src = self;
          inherit version;
        };
      };

      packages = forAllSystems (pkgs: {
        default = pkgs.prusa-slicer-alpha;
        prusa-slicer = pkgs.prusa-slicer-alpha;
        # Same build with the Catch2 test suites compiled and run.
        prusa-slicer-tested = pkgs.prusa-slicer-alpha.override { doCheck = true; };
        # Dependencies that are not in nixpkgs, exposed for debugging.
        inherit (pkgs.prusa-slicer-alpha.passthru)
          libassert
          yoga
          prusa-fdm-mixer
          libbgcode
          ;
      });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = lib.getExe pkgs.prusa-slicer-alpha;
        };
      });

      devShells = forAllSystems (pkgs: {
        # All build inputs of the package, for hacking on PrusaSlicer itself:
        #   nix develop
        #   cmake --preset shareddeps -G Ninja $cmakeFlags && cmake --build shareddeps
        default = pkgs.mkShell {
          inputsFrom = [ pkgs.prusa-slicer-alpha ];
          packages = [
            pkgs.ccache
            pkgs.gdb
          ];
          inherit (pkgs.prusa-slicer-alpha) cmakeFlags;
        };
      });

      checks = forAllSystems (pkgs: {
        build = pkgs.prusa-slicer-alpha;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
