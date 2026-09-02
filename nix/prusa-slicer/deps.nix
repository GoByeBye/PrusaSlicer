{
  lib,
  stdenv,
  fetchurl,
  cmake,
  git,
  pkg-config,
  perl,
  python3,
  m4,
  autoconf,
  automake,
  libtool,
  texinfo,
  nasm,
  zlib,
  libGL,
  libGLU,
  gtk3,
  glib,
  webkitgtk_4_1,
  dbus,
  libxkbcommon,
  libX11,
  libXext,
  libXrandr,
  libXinerama,
  libXcursor,
  libXi,
  libXfixes,
  libxxf86vm,
  xorgproto,
  # The PrusaSlicer source tree (only deps/ and cmake/ are used).
  src,
  version,
}:

let
  # Archive pinned by each deps/+<name>/<name>.cmake recipe (see nix/update-deps-sources.py).
  sources = import ./deps-sources.nix;

  fetched = map (s: {
    inherit (s) name;
    file = baseNameOf s.url;
    archive = fetchurl {
      name = "prusaslicer-dep-${s.name}-${baseNameOf s.url}";
      inherit (s) url sha256;
    };
  }) sources;

  # Packages that are excluded from the dependency build. This is a CMake regex
  # matched against each package name (PrusaSlicer_deps_PACKAGE_EXCLUDES).
  #   sentry  - only linked when SLIC3R_SENTRY_DSN is set; the crashpad backend is
  #             not useful in a Nix build.
  #   OpenCSG - already EXCLUDE_FROM_ALL upstream (only used by sandboxes).
  excludes = "sentry|OpenCSG";

  # Only deps/ and cmake/ take part in this build. Restricting the source keeps
  # the (very long) dependency build from being invalidated by unrelated edits.
  depsSrc =
    if builtins.isPath src then
      lib.fileset.toSource {
        root = src;
        fileset = lib.fileset.unions [
          (src + "/deps")
          (src + "/cmake")
        ];
      }
    else
      src;
in
stdenv.mkDerivation {
  pname = "prusa-slicer-deps";
  inherit version;

  src = depsSrc;

  # The superproject lives in deps/; it refers to ../cmake/modules.
  cmakeDir = "../deps";

  nativeBuildInputs = [
    cmake
    git # deps/CMakeLists.txt applies patches with `git apply`
    pkg-config
    perl # OpenSSL
    python3 # z3 generates sources with Python
    m4 # GMP
    autoconf # MPFR runs autoreconf
    automake
    libtool
    texinfo
    nasm # libjpeg-turbo SIMD
  ];

  buildInputs = [
    zlib # the only library the superproject expects from the system on UNIX
    libGL
    libGLU
    gtk3
    glib
    webkitgtk_4_1 # wxWidgets is built with wxUSE_WEBVIEW=ON
    dbus
    libxkbcommon
    libX11
    libXext
    libXrandr
    libXinerama
    libXcursor
    libXi
    libXfixes
    libxxf86vm
    xorgproto
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DPrusaSlicer_deps_DEP_INSTALL_PREFIX=${placeholder "out"}"
    "-DPrusaSlicer_deps_PACKAGE_EXCLUDES=${excludes}"
  ];

  # Every dependency is an ExternalProject that would download its archive at
  # build time. Pre-populate the download directory instead: ExternalProject
  # checks <DOWNLOAD_DIR>/<archive basename> against URL_HASH and skips the
  # download when the file is already there and the hash matches.
  preConfigure = ''
    downloads="$NIX_BUILD_TOP/downloads"
    ${lib.concatMapStringsSep "\n" (d: ''
      mkdir -p "$downloads/${d.name}"
      ln -s "${d.archive}" "$downloads/${d.name}/${d.file}"
    '') fetched}
    cmakeFlagsArray+=("-DPrusaSlicer_deps_DEP_DOWNLOAD_DIR=$downloads")

    # Each dependency builds in parallel on its own; the superproject itself is
    # built serially (as upstream recommends).
    if [ "''${NIX_BUILD_CORES:-0}" -gt 0 ]; then
      cmakeFlagsArray+=("-DDEP_MAX_THREADS=$NIX_BUILD_CORES")
    fi
  '';

  enableParallelBuilding = false;

  # Libraries are installed into $out by the individual ExternalProjects during
  # the build step; the superproject's own install step only prints a message.
  # Keep the default installPhase so that message-only step still runs.

  # The cmake hook rewrites "/usr" paths in every CMake file of the source tree.
  # The recipes are used verbatim by upstream; leave them alone.
  dontFixCmake = true;

  requiredSystemFeatures = [ "big-parallel" ];

  meta = {
    description = "Statically built third-party dependencies for PrusaSlicer ${version}";
    homepage = "https://github.com/prusa3d/PrusaSlicer";
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.linux;
  };
}
