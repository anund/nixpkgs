{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmUpdateScript,
  cmake,
  rocm-cmake,
  rocblas,
  rocprim,
  rocsparse,
  clr,
  fmt,
  gtest,
  gfortran,
  lapack-reference,
  buildTests ? false,
  buildBenchmarks ? false,
  gpuTargets ? (clr.localGpuTargets or [ ]),
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "rocsolver${clr.gpuArchSuffix}";
  version = "10.0";

  outputs = [
    "out"
  ]
  ++ lib.optionals buildTests [
    "test"
  ]
  ++ lib.optionals buildBenchmarks [
    "benchmark"
  ];

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-libraries";
    tag = "therock-${finalAttrs.version}";
    sparseCheckout = [
      "projects/rocsolver"
      "shared"
    ];
    hash = "sha256-JvY6zOgUMSeVNYP4VVvoXx8CcMv/6uQy1tb7BpsxcSg=";
  };
  sourceRoot = "${finalAttrs.src.name}/projects/rocsolver";

  nativeBuildInputs = [
    cmake
    # no ninja, it buffers console output and nix times out long periods of no output
    rocm-cmake
    clr
  ]
  ++ lib.optionals (buildTests || buildBenchmarks) [
    gfortran
  ];

  buildInputs = [
    # FIXME: rocblas and rocsolver can't build in parallel
    # but rocsolver doesn't need rocblas' offload builds at build time
    # could we build against a rocblas-minimal?
    rocblas
    rocprim
    rocsparse
    fmt
  ]
  ++ lib.optionals buildTests [
    gtest
  ]
  ++ lib.optionals (buildTests || buildBenchmarks) [
    lapack-reference
  ];

  cmakeFlags = [
    "-DHIP_CLANG_NUM_PARALLEL_JOBS=4"
    "-DCMAKE_VERBOSE_MAKEFILE=ON"
    # Manually define CMAKE_INSTALL_<DIR>
    # See: https://github.com/NixOS/nixpkgs/pull/197838
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
  ]
  ++ lib.optionals (gpuTargets != [ ]) [
    #https://github.com/ROCm/rocm-libraries/blob/therock-10.0/projects/rocsolver/CMakeLists.txt#L173
    "-DAMDGPU_TARGETS=${lib.concatStringsSep ";" gpuTargets}"
  ]
  ++ lib.optionals buildTests [
    "-DBUILD_CLIENTS_TESTS=ON"
  ]
  ++ lib.optionals buildBenchmarks [
    "-DBUILD_CLIENTS_BENCHMARKS=ON"
  ];

  postInstall =
    lib.optionalString buildTests ''
      mkdir -p $test/bin
      mv $out/bin/rocsolver-test $test/bin
    ''
    + lib.optionalString buildBenchmarks ''
      mkdir -p $benchmark/bin
      mv $out/bin/rocsolver-bench $benchmark/bin
    ''
    + lib.optionalString (buildTests || buildBenchmarks) ''
      rmdir $out/bin
    '';

  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  requiredSystemFeatures = [ "big-parallel" ];

  meta = {
    description = "ROCm LAPACK implementation";
    homepage = "https://github.com/ROCm/rocm-libraries/tree/develop/projects/rocsolver";
    license = lib.licenses.bsd2;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
    timeout = 14400; # 4 hours
    maxSilent = 14400; # 4 hours
  };
})
