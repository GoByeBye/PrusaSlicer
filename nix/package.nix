{
  lib,
  stdenv,
  clangStdenv,
  callPackage,
  fetchFromGitHub,
  runtimeShell,

  # build tools
  cmake,
  ninja,
  pkg-config,
  wrapGAppsHook3,

  # libraries
  boost186,
  onetbb,
  nlopt,
  expat,
  libpng,
  libjpeg_turbo,
  zlib,
  zstd,
  glew,
  libGL,
  glfw,
  SDL2,
  cereal,
  eigen,
  fmt,
  tracy,
  openvdb,
  c-blosc,
  libbgcode,
  heatshrink,
  opencascade-occt_7_6_1,
  nanosvg,
  gtk3,
  glib,
  glib-networking,
  dbus,
  webkitgtk_4_1,
  fontconfig,
  hicolor-icon-theme,
  cli11,
  tl-expected,
  spdlog,
  cpptrace,
  libdwarf,
  qhull,
  cgal_5,
  gmp,
  mpfr,
  openssl,
  lua5_4,
  sol2,
  wxwidgets_3_3,
  nlohmann_json,
  pugixml,
  rapidyaml,
  magic-enum,
  range-v3,
  libdeflate,
  curl,
  catch2_3,
  trompeloeil,
  ctestCheckHook,

  # package options
  # Source tree to build. Defaults to the upstream release tag; the flake passes
  # the checkout itself so `nix build` builds the working tree.
  src ? null,
  version ? "3.0.0-alpha11",
  # GCC needs an enormous amount of memory on this code base; nixpkgs builds
  # the 2.9 series with clang for the same reason.
  useClang ? true,
  # Link against WebKitGTK for the embedded browser (login, Printables, ...).
  withWebKit ? true,
  # STEP import via OpenCASCADE (built as the OCCTWrapper plugin).
  withStep ? true,
  # Upstream forces GDK_BACKEND=x11. nixpkgs drops that for 2.9 because wxGTK
  # works fine on Wayland nowadays; keep the same default here.
  allowWayland ? true,
  # Build and run the Catch2 test suites. Off by default: it roughly doubles
  # the build and this is an alpha.
  doCheck ? false,
}:

let
  stdenv' = if useClang then clangStdenv else stdenv;

  src' =
    if src != null then
      src
    else
      fetchFromGitHub {
        owner = "prusa3d";
        repo = "PrusaSlicer";
        tag = "version_${version}";
        hash = "sha256-U+5CYJ6mykZA37uqPKeDyKcQfTmgG1BCRV8dVhLWTHs=";
      };

  # --- dependencies that need a specific fork / revision / patch ------------

  # Upstream switched from memononen/nanosvg to the fltk fork in 2.6.0 because
  # of nsvgRasterizeXY(); same pin as deps/+NanoSVG/NanoSVG.cmake.
  nanosvg-fltk = nanosvg.overrideAttrs (old: {
    pname = "nanosvg-fltk";
    version = "0-unstable-2022-12-22";
    src = fetchFromGitHub {
      owner = "fltk";
      repo = "nanosvg";
      rev = "abcd277ea45e9098bed752cf9c6875b533c0892f";
      hash = "sha256-WNdAYu66ggpSYJ8Kt57yEA4mSTv+Rvzj9Rm1q765HpY=";
    };
  });

  # 3.0 uses binarize/convert APIs newer than the snapshot in nixpkgs; use the
  # revision pinned in deps/+LibBGCode/LibBGCode.cmake.
  libbgcode' = libbgcode.overrideAttrs (old: {
    version = "0-unstable-2026-07-22";
    src = fetchFromGitHub {
      owner = "prusa3d";
      repo = "libbgcode";
      rev = "d4da9073616d70a43c151e8c1d7fbff879d2e08a";
      hash = "sha256-VYb7DSN+V8mFGiTEurlCkkYYT+0dWLGV2iTNsBchQj4=";
    };
  });

  # PrusaSlicer builds nlohmann_json with implicit conversions disabled and
  # carries a fix for std::optional support in 3.12.0 (deps/+json/json.patch).
  nlohmann_json' = nlohmann_json.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ "${src'}/deps/+json/json.patch" ];
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [ (lib.cmakeBool "JSON_ImplicitConversions" false) ];
    doCheck = false;
  });

  libassert = callPackage ./libassert.nix { stdenv = stdenv'; };
  yoga = callPackage ./yoga.nix {
    stdenv = stdenv';
    prusaSrc = src';
  };
  prusa-fdm-mixer = callPackage ./prusa-fdm-mixer.nix {
    stdenv = stdenv';
    prusaSrc = src';
  };
in
stdenv'.mkDerivation (finalAttrs: {
  pname = "prusa-slicer";
  inherit version;
  src = src';

  postPatch = ''
    # wxWidgets from nixpkgs is built with autotools and ships no CMake
    # package config, so search it in module mode (wx-config). The bundled
    # FindwxWidgets.cmake provides the wxWidgets::wxWidgets target as well.
    substituteInPlace src/slic3r-platform-wx/CMakeLists.txt \
      --replace-fail 'find_package(wxWidgets 3.3 CONFIG REQUIRED' 'find_package(wxWidgets 3.3 REQUIRED'

    # nixpkgs only ships the shared libdeflate library.
    substituteInPlace src/slic3r-shared/CMakeLists.txt \
      --replace-fail 'libdeflate::libdeflate_static' 'libdeflate::libdeflate_shared'

    # The STEP importer dlopen()s OCCTWrapper.so next to the executable. With
    # the executable wrapped by wrapGAppsHook it is simpler and more robust to
    # give it a fixed location in the store.
    substituteInPlace src/slic3r-shared/src/Slic3r/Biz/Format/STEP.cpp \
      --replace-fail 'auto libpath = boost::dll::program_location().parent_path();' \
                     'auto libpath = boost::filesystem::path("'"$out"'/lib/prusa-slicer");'

    # Identify the build.
    substituteInPlace version.inc --replace-fail '+UNKNOWN' '+nix'

    # The desktop file is written for the flatpak layout.
    substituteInPlace src/platform/unix/com.prusa3d.PrusaSlicer.desktop.in \
      --replace-fail 'Exec=/app/bin/slic3r-app-launcher' 'Exec=prusa-slicer'
  ''
  + lib.optionalString allowWayland ''
    substituteInPlace src/slic3r-app-desktop/src/Slic3r/App/Desktop/DesktopApp.cpp \
      --replace-fail '::setenv("GDK_BACKEND", "x11", /* replace */ true);' \
                     '/* GDK_BACKEND is left alone; see allowWayland in package.nix */'
  '';

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    wrapGAppsHook3
    wxwidgets_3_3 # wx-config is run at configure time
  ];

  buildInputs = [
    boost186 # deps pin 1.86; 2.9 is known not to build with 1.87+
    onetbb
    nlopt
    expat
    libpng
    libjpeg_turbo
    zlib
    zstd
    glew
    libGL
    glfw
    SDL2
    cereal
    eigen
    fmt
    tracy
    openvdb
    c-blosc
    libbgcode'
    heatshrink
    nanosvg-fltk
    gtk3
    glib
    glib-networking
    dbus
    fontconfig
    hicolor-icon-theme
    cli11
    tl-expected
    spdlog
    libassert
    cpptrace
    libdwarf
    qhull
    prusa-fdm-mixer
    cgal_5
    gmp
    mpfr
    openssl
    lua5_4
    sol2
    wxwidgets_3_3
    yoga
    nlohmann_json'
    pugixml
    rapidyaml
    magic-enum
    range-v3
    libdeflate
    curl
  ]
  ++ lib.optionals withWebKit [ webkitgtk_4_1 ]
  ++ lib.optionals withStep [ opencascade-occt_7_6_1 ]
  ++ lib.optionals doCheck [
    catch2_3
    trompeloeil
  ];

  strictDeps = true;

  cmakeFlags = [
    (lib.cmakeBool "SLIC3R_STATIC" false)
    (lib.cmakeBool "SLIC3R_FHS" true)
    (lib.cmakeBool "SLIC3R_GUI" true)
    (lib.cmakeBool "SLIC3R_PCH" true)
    (lib.cmakeBool "SLIC3R_ENABLE_FORMAT_STEP" withStep)
    (lib.cmakeBool "SLIC3R_ENABLE_WEBKIT" withWebKit)
    (lib.cmakeBool "SLIC3R_BUILD_TESTS" doCheck)
    (lib.cmakeFeature "SLIC3R_YAML" "ryml")
    # bundled_deps still contain cmake_minimum_required() < 3.5
    (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
  ];

  inherit doCheck;
  nativeCheckInputs = [ ctestCheckHook ];
  checkFlags = [ "--force-new-ctest-process" ];

  postInstall = ''
    # Keep the STEP plugin where STEP.cpp was patched to look for it.
    mkdir -p $out/lib/prusa-slicer
    mv $out/bin/OCCTWrapper.so $out/lib/prusa-slicer/ 2>/dev/null || true

    # slic3r-app-cli is a static library that CMake installs anyway.
    rm -f $out/lib/*.a

    ln -s slic3r-app-launcher $out/bin/prusa-slicer
    cat > $out/bin/prusa-gcodeviewer <<EOF
    #!${runtimeShell}
    exec "$out/bin/prusa-slicer" --gcodeviewer "\$@"
    EOF
    chmod +x $out/bin/prusa-gcodeviewer

    install -Dm644 com.prusa3d.PrusaSlicer.desktop -t $out/share/applications
    install -Dm644 ../src/platform/unix/PrusaGcodeviewer.desktop \
      $out/share/applications/com.prusa3d.PrusaGcodeviewer.desktop
    substituteInPlace $out/share/applications/com.prusa3d.PrusaGcodeviewer.desktop \
      --replace-fail 'Exec=prusa-slicer --gcodeviewer %F' 'Exec=prusa-gcodeviewer %F' \
      --replace-fail 'MimeType=text/x.gcode;' 'MimeType=application/x-bgcode;text/x.gcode;'

    install -Dm644 ../resources/icons/PrusaSlicer.svg \
      $out/share/icons/hicolor/scalable/apps/com.prusa3d.PrusaSlicer.svg
    install -Dm644 ../resources/icons/PrusaSlicer_128px.png \
      $out/share/icons/hicolor/128x128/apps/com.prusa3d.PrusaSlicer.png
    install -Dm644 ../resources/icons/PrusaSlicer-gcodeviewer.svg \
      $out/share/icons/hicolor/scalable/apps/PrusaSlicer-gcodeviewer.svg

    mkdir -p $out/share/mime/packages
    cat > $out/share/mime/packages/prusa-gcode-viewer.xml <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
      <mime-type type="application/x-bgcode">
        <comment xml:lang="en">Binary G-code file</comment>
        <glob pattern="*.bgcode"/>
      </mime-type>
    </mime-info>
    EOF
  '';

  passthru = {
    inherit
      libassert
      yoga
      prusa-fdm-mixer
      nanosvg-fltk
      ;
    libbgcode = libbgcode';
    nlohmann_json = nlohmann_json';
  };

  meta = {
    description = "G-code generator for 3D printers (3.0 alpha)";
    longDescription = ''
      PrusaSlicer takes 3D models (STL, OBJ, AMF, 3MF, STEP) and converts them
      into G-code instructions for FFF printers or PNG layers for mSLA 3D
      printers. This is the 3.0 development series with the new UI stack.
    '';
    homepage = "https://github.com/prusa3d/PrusaSlicer";
    changelog = "https://github.com/prusa3d/PrusaSlicer/releases/tag/version_${version}";
    license = lib.licenses.agpl3Plus;
    mainProgram = "prusa-slicer";
    platforms = lib.platforms.linux;
  };
})
