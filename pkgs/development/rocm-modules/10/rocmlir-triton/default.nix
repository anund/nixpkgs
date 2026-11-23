{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmUpdateScript,
  cmake,
  rocm-cmake,
  clr,
  libxml2,
  libedit,
  rocm-comgr,
  rocm-device-libs,
  rocm-runtime,
  zstd,
  zlib,
  ncurses,
  python3Packages,
  writableTmpDirAsHomeHook,
  buildRockCompiler ? false,
  buildTests ? false,
}:

let
  suffix = if buildRockCompiler then "-rock" else "";

  llvmNativeTarget =
    if stdenv.hostPlatform.isx86_64 then
      "X86"
    else if stdenv.hostPlatform.isAarch64 then
      "AArch64"
    else
      throw "Unsupported ROCm LLVM platform";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "rocmlir-triton${suffix}";
  version = "unstable-2026-10-21";

  outputs = [
    "out"
  ]
  ++ lib.optionals (!buildRockCompiler) [
    "external"
  ];

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocmlirTriton";
    rev = "72b2f2b4067cbd77486364448e08ca45527c48cf";
    hash = "sha256-YCMIUw5oOIFbNJ2i4YRZKNNg8RqZhky8h0FwuXU7obw=";
  };

  nativeBuildInputs = [
    clr
    cmake
    rocm-cmake
    writableTmpDirAsHomeHook
    python3Packages.python
    python3Packages.tomli
    python3Packages.pybind11
  ];

  buildInputs = [
    libxml2
    libedit
    rocm-comgr
    rocm-runtime
    rocm-device-libs
  ];

  propagatedBuildInputs = [
    zstd
    zlib
    ncurses
  ];

  cmakeFlags = [
    (lib.cmakeFeature "LLVM_TARGETS_TO_BUILD" "AMDGPU;${llvmNativeTarget}")
    (lib.cmakeFeature "LLVM_USE_LINKER" "lld")
    (lib.cmakeFeature "LLVM_ENABLE_ZSTD" "FORCE_ON")
    (lib.cmakeFeature "LLVM_ENABLE_ZLIB" "FORCE_ON")
    (lib.cmakeBool "LLVM_ENABLE_LIBCXX" true)
    (lib.cmakeFeature "ROCM_PATH" "${clr}")
    # Manually define CMAKE_INSTALL_<DIR>
    # See: https://github.com/NixOS/nixpkgs/pull/197838
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
    (lib.cmakeBool "MLIR_ENABLE_ROCM_RUNNER" (!buildRockCompiler))
    (lib.cmakeBool "BUILD_FAT_LIBROCKCOMPILER" buildRockCompiler)
    (lib.cmakeBool "MLIR_INCLUDE_TESTS" false)
  ]
  ++ lib.optionals buildRockCompiler [
    (lib.cmakeBool "LLVM_INCLUDE_TESTS" false)
  ]
  ++ lib.optionals (!buildRockCompiler) [
    (lib.cmakeFeature "ROCM_TEST_CHIPSET" "gfx900")
  ];

  postPatch = ''
    patchShebangs mlir
    patchShebangs external/llvm-project/mlir

    substituteInPlace mlir/utils/performance/common/CMakeLists.txt \
      --replace-fail " PATHS /opt/rocm" ""
  '';

  dontBuild = true;
  doCheck = true;

  # Certain libs aren't being generated, try enabling tests next update
  checkTarget =
    if buildRockCompiler then
      "librockCompiler"
    else if buildTests then
      "check-rocmlir"
    else
      "check-rocmlir-build-only";

  postInstall =
    let
      libPath = lib.makeLibraryPath [
        zstd
        zlib
        ncurses
        clr
        stdenv.cc.cc
      ];
    in
    lib.optionalString (!buildRockCompiler) ''
      mkdir -p $external/lib
      cp -a external/llvm-project/llvm/lib/{*.a*,*.so*} $external/lib
      patchelf --set-rpath $external/lib:$out/lib:${libPath} $external/lib/*.so*
      patchelf --set-rpath $out/lib:$external/lib:${libPath} $out/{bin/*,lib/*.so*}
    '';

  passthru.updateScript = rocmUpdateScript {
    inherit finalAttrs;
    page = "tags";
  };

  meta = {
    description = "rocmlirTriton is a Triton-backed GPU kernel generator derived from rocMLIR using a different codegen approach";
    homepage = "rocmlirTriton";
    license = lib.licenses.asl20;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})
