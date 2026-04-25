{
  lib,
  stdenv,
  fetchurl,
  fetchpatch,
}:

# This package only provides the bluetooth headers from the bluez package
# for consumption in Python, which cannot consume bluez.dev due to multiple
# infinite recursion paths.

stdenv.mkDerivation (finalAttrs: {
  pname = "bluez-headers";
  version = "5.86";

  # This package has the source, because of the emulatorAvailable check in the
  # bluez function args, that causes an infinite recursion with Python on cross
  # builds.
  src = fetchurl {
    url = "mirror://kernel/linux/bluetooth/bluez-${finalAttrs.version}.tar.xz";
    hash = "sha256-mfFEVAxgcFkeTFO8uXfrQmZMYrezbLNaKc9y3tM5Yh0=";
  };

  patches = [
    # can be removed after an update to 5.87
    (fetchpatch {
      url = "https://github.com/bluez/bluez/commit/b33e923b55e4d0e9d78a83cfcb541fd1f687ef54.patch";
      hash = "sha256-tp9cLBvCAyDThTuJ3rJXxwSQIAoM+qIJGnshA6wnncI=";
    })
    (fetchpatch {
      url = "https://github.com/bluez/bluez/commit/21e13976f2e375d701b8b7032ba5c1b2e56c305f.patch";
      hash = "sha256-Tq4O+heetVJG3I2Bm2PnXT8pVvqcAPXOQpzeyQwomrY=";
    })
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/include/
    cp -rv lib/* "$out/include/"
  '';

  meta = {
    homepage = "https://www.bluez.org/";
    description = "Official Linux Bluetooth protocol stack";
    changelog = "https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/ChangeLog?h=${finalAttrs.version}";
    license = with lib.licenses; [
      bsd2
      gpl2Plus
      lgpl21Plus
      mit
    ];
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };
})
