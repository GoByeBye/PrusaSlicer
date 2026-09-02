{
  lib,
  stdenv,
  cmake,
  pkg-config,
  wrapGAppsHook3,
  prusa-slicer-deps,
  zlib,
  dbus,
  gtk3,
  glib,
  glib-networking,
  gsettings-desktop-schemas,
  hicolor-icon-theme,
  webkitgtk_4_1,
  libGL,
  libGLU,
  libxkbcommon,
  libX11,
  libXext,
  libXrandr,
  libXinerama,
  libXcursor,
  libXi,
  libXfixes,
  libxxf86vm,
  cacert,
  # The PrusaSlicer source tree.
  src,
  version,
  withStep ? true, # STEP import through OpenCASCADE (OCCTWrapper.so)
  withWebkit ? true, # embedded browser (Prusa Connect / login pages)
  withTests ? false,
}:

let
  # Everything that is not part of the application build is filtered out so
  # that touching the Nix files or the dependency recipes does not rebuild the
  # application.
  appSrc =
    if builtins.isPath src then
      lib.fileset.toSource {
        root = src;
        fileset = lib.fileset.difference src (
          lib.fileset.unions [
            (lib.fileset.maybeMissing (src + "/deps"))
            (lib.fileset.maybeMissing (src + "/nix"))
            (lib.fileset.maybeMissing (src + "/flake.nix"))
            (lib.fileset.maybeMissing (src + "/flake.lock"))
            (lib.fileset.maybeMissing (src + "/.github"))
          ]
        );
      }
    else
      src;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "prusa-slicer";
  inherit version;

  src = appSrc;

  nativeBuildInputs = [
    cmake
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    prusa-slicer-deps
    zlib
    dbus # find_package(DBus1)
    gtk3
    glib
    glib-networking # TLS for the WebKit views
    gsettings-desktop-schemas
    hicolor-icon-theme
    libGL
    libGLU
    libxkbcommon
    libX11
    libXext
    libXrandr
    libXinerama
    libXcursor
    libXi
    libXfixes
    libxxf86vm
  ] ++ lib.optional withWebkit webkitgtk_4_1;

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    # Link the statically built dependency bundle.
    "-DSLIC3R_STATIC=ON"
    "-DCMAKE_PREFIX_PATH=${prusa-slicer-deps}"
    # Resources go to $out/share/PrusaSlicer instead of next to the binary.
    "-DSLIC3R_FHS=ON"
    "-DSLIC3R_GUI=ON"
    "-DSLIC3R_PCH=OFF"
    (lib.cmakeBool "SLIC3R_ENABLE_FORMAT_STEP" withStep)
    (lib.cmakeBool "SLIC3R_ENABLE_WEBKIT" withWebkit)
    (lib.cmakeBool "SLIC3R_BUILD_TESTS" withTests)
  ];

  doCheck = withTests;

  postInstall = ''
    # 3.0 renamed the executable; keep the familiar name around.
    ln -s slic3r-app-launcher $out/bin/prusa-slicer
    ln -s slic3r-app-cli $out/bin/prusa-slicer-cli

    # Desktop integration. The configured desktop file targets the flatpak
    # layout (/app/bin); point it at the store path instead.
    install -Dm644 com.prusa3d.PrusaSlicer.desktop \
      $out/share/applications/com.prusa3d.PrusaSlicer.desktop
    substituteInPlace $out/share/applications/com.prusa3d.PrusaSlicer.desktop \
      --replace-fail "/app/bin/" "$out/bin/"

    install -Dm644 $out/share/PrusaSlicer/icons/PrusaSlicer.svg \
      $out/share/icons/hicolor/scalable/apps/com.prusa3d.PrusaSlicer.svg
    install -Dm644 $out/share/PrusaSlicer/icons/PrusaSlicer_128px.png \
      $out/share/icons/hicolor/128x128/apps/com.prusa3d.PrusaSlicer.png
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      # The vendored curl is built without a CA bundle path; PrusaSlicer looks
      # for certificates at runtime (OPENSSL_CERT_OVERRIDE). Give it a default.
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt"
      # WebKitGTK renders blank views on some (notably NVIDIA) drivers without this.
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
    )
  '';

  requiredSystemFeatures = [ "big-parallel" ];

  meta = {
    description = "G-code generator for 3D printers (Prusa, Voron, Creality, ...)";
    longDescription = ''
      PrusaSlicer converts 3D models into G-code instructions for 3D printers.
      This is the 3.0 alpha series, built from the source tree in this repository
      against its pinned, statically linked dependency bundle.
    '';
    homepage = "https://github.com/prusa3d/PrusaSlicer";
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "prusa-slicer";
  };
})
