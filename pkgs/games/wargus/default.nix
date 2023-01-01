{ stdenv
, lib
, callPackage
, fetchFromGitHub
, cmake
, pkg-config
, makeWrapper
, zlib
, bzip2
, libpng
, ffmpeg
, cdData ? null
, expansionData ? null
}:

let
  stratagus = callPackage ./stratagus.nix {};

in
stdenv.mkDerivation rec {
  pname = "wargus";
  inherit (stratagus) version;

  src = fetchFromGitHub {
    owner = "wargus";
    repo = "wargus";
    rev = "v${version}";
    sha256 = "sha256-yJeMFxCD0ikwVPQApf+IBuMQ6eOjn1fVKNmqh6r760c=";
  };

  nativeBuildInputs = [ cmake pkg-config makeWrapper ffmpeg ];
  buildInputs = [ zlib bzip2 libpng ];
  cmakeFlags = [
    "-DSTRATAGUS=${stratagus}/games/stratagus"
    "-DSTRATAGUS_INCLUDE_DIR=${stratagus.src}/gameheaders"
  ];
  postInstall = ''
    makeWrapper $out/games/wargus $out/bin/wargus \
      --prefix PATH : ${lib.makeBinPath [ "$out" ]}
    substituteInPlace $out/share/applications/wargus.desktop \
      --replace $out/games/wargus $out/bin/wargus

    ${lib.optionalString (cdData != null)
      ''$out/bin/wartool -v -r ${cdData} $out/share/games/stratagus/wargus''
    }
    ${lib.optionalString (expansionData != null)
      ''$out/bin/wartool -v -r ${expansionData} $out/share/games/stratagus/wargus''
    }
    install -Dm755 $out/share/pixmaps/wargus.png $out/share/icons/hicolor/64x64/apps/wargus.png
    ln -s $out/share/games/stratagus/wargus/{contrib/black_title.png,graphics/ui/black_title.png}
  '';

  meta = with lib; {
    description = "Importer and scripts for Warcraft II: Tides of Darkness, the expansion Beyond the Dark Portal, and Aleonas Tales";
    homepage = "https://wargus.github.io/";
    license = licenses.gpl2Only;
    maintainers = [ maintainers.astro ];
    platforms = platforms.linux;
  };
}
