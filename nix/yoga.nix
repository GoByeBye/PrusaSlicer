{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  prusaSrc,
}:

# Facebook's Yoga layout engine. PrusaSlicer 3.0 uses it for the new imgui based
# UI. nixpkgs does not package the C++ library, so build the version pinned in
# deps/+yoga/yoga.cmake with the same patch PrusaSlicer applies (keeps RTTI on,
# drops the tests).
stdenv.mkDerivation (finalAttrs: {
  pname = "yoga";
  version = "3.1.0";

  src = fetchFromGitHub {
    owner = "facebook";
    repo = "yoga";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Y/BHMAfMUBY2Z5VV6rZkBGMs8II+r6MWXM6oV+nxtaQ=";
  };

  patches = [ "${prusaSrc}/deps/+yoga/yoga.patch" ];

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
  ];

  # yoga's project-defaults.cmake turns on -Werror; do not let a newer compiler
  # break the build over a warning.
  env.NIX_CFLAGS_COMPILE = "-Wno-error";

  meta = {
    description = "Embeddable and performant flexbox layout engine";
    homepage = "https://github.com/facebook/yoga";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
