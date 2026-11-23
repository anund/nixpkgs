{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmUpdateScript,
  cmake,
  rocm-cmake,
  clr,
  rocprofiler-register,
  util-linuxMinimal,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hipfile";
  version = "10.0";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-systems";
    tag = "therock-${finalAttrs.version}";
    sparseCheckout = [
      "projects/hipfile"
      "shared"
    ];
    hash = "sha256-QyBNUECreflWBYTv0SejNIE4ID8FAk4V1c7a5oz+Io4=";
  };
  sourceRoot = "${finalAttrs.src.name}/projects/hipfile";

  nativeBuildInputs = [
    cmake
    rocm-cmake
    clr
  ];

  buildInputs = [
    util-linuxMinimal
    rocprofiler-register
  ];

  env.CXXFLAGS = "-I${util-linuxMinimal.dev}/include";
  cmakeFlags = [
    (lib.cmakeFeature "ROCM_PATH" "${clr}")
  ];

  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  meta = {
    description = "hipFile is AMD's Infinity Storage library that provides direct-to-GPU I/O for the ROCm platform";
    homepage = "https://github.com/ROCm/rocm-systems/tree/develop/projects/hipfile";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})
