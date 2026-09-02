{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  prusaSrc,
}:

# Prusa's multi-material mixing model. The upstream repository is mostly a web
# app; the C++ part lives in cpp/ and has no install rules of its own, so
# PrusaSlicer ships a replacement CMakeLists.txt in deps/+prusa_fdm_mixer.
stdenv.mkDerivation {
  pname = "prusa-fdm-mixer";
  version = "0-unstable-2026-07-02";

  src = fetchFromGitHub {
    owner = "prusa3d";
    repo = "prusa-fdm-mixer";
    rev = "09d372aeccb4f7b9a0efbe59d99d70dba196814a";
    hash = "sha256-3t4K+T8uRaAyhbTQTwM+sEmbYCAMrsh4jaGtTLKxMGw=";
  };

  sourceRoot = "source/cpp";

  postPatch = ''
    cp ${prusaSrc}/deps/+prusa_fdm_mixer/CMakeLists.txt ./CMakeLists.txt
    cp ${prusaSrc}/deps/+prusa_fdm_mixer/Config.cmake.in ./Config.cmake.in
  '';

  nativeBuildInputs = [ cmake ];

  meta = {
    description = "Prusa FDM colour mixing library";
    homepage = "https://github.com/prusa3d/prusa-fdm-mixer";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
