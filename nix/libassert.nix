{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  cpptrace,
  libdwarf,
  zstd,
}:

# libassert is not packaged in nixpkgs yet. PrusaSlicer 3.0 pins v2.2.1 in
# deps/+LibAssert/LibAssert.cmake and builds it against an external cpptrace,
# which is what we do here as well.
stdenv.mkDerivation (finalAttrs: {
  pname = "libassert";
  version = "2.2.1";

  src = fetchFromGitHub {
    owner = "jeremy-rifkin";
    repo = "libassert";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ognudQ3NgpYxiDEucbIRWYQPs0XLRUQwg1eMxJm+aPs=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    libdwarf
    zstd
  ];

  # libassertConfig.cmake does find_dependency(cpptrace), so consumers need it too.
  propagatedBuildInputs = [ cpptrace ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeBool "LIBASSERT_USE_EXTERNAL_CPPTRACE" true)
    (lib.cmakeBool "LIBASSERT_BUILD_TESTING" false)
  ];

  meta = {
    description = "Most over-engineered C++ assertion library";
    homepage = "https://github.com/jeremy-rifkin/libassert";
    changelog = "https://github.com/jeremy-rifkin/libassert/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
