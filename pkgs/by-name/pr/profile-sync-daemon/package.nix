{
  lib,
  stdenv,
  fetchFromGitHub,
  util-linux,
  coreutils,
  fuse-overlayfs,
  fuse3,
  gnugrep,
  gawk,
  findutils,
  rsync,
  kmod,
  net-tools,
  ncurses,
  gnused,
  systemd,
  procps,
  resholve,
  bash,
  getent,
  glib,
  runCommand,
  writableTmpDirAsHomeHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "profile-sync-daemon";
  version = "7.03";

  src = fetchFromGitHub {
    owner = "graysky2";
    repo = "profile-sync-daemon";
    rev = "v${finalAttrs.version}";
    hash = "sha256-iaNDAGVv5DNVRjiwANwSirHf0AbTnxcf5YQEpCoM6qM=";
  };

  #  patches = [
  #    ./path.patch
  #  ];

  installPhase =
    let
      deps = [
        fuse-overlayfs
        fuse3
        gnugrep
        gawk
        findutils
        util-linux
        coreutils
        rsync
        kmod
        net-tools
        util-linux
        ncurses
        gnused
        systemd
        procps
        getent
        glib
      ];
      path = lib.makeBinPath deps;
    in
    ''
      PREFIX=\"\" DESTDIR=$out make install
      substituteInPlace $out/bin/profile-sync-daemon \
        --replace-fail 'if [[ ! -x /usr/bin/"''$_bin" ]]; then' 'if ! command -v "''$_bin" >/dev/null 2>&1; then' \
        --replace-fail  "/usr/" "$out/" \
        --replace-fail "fusermount3 " "/run/wrappers/bin/fusermount3 "\
        --replace-fail 'PATH=''$PATH:/sbin' 'PATH=${path}'
      substituteInPlace $out/bin/psd-suspend-sync \
        --replace-fail  "/usr/bin/profile-sync-daemon" "$out/bin/profile-sync-daemon"
      ${resholve.phraseSolution "profile-sync-daemon" {
        scripts = [
          "bin/profile-sync-daemon"
          "bin/psd-suspend-sync"
        ];
        interpreter = "${bash}/bin/bash";
        keep = {
          source = [
            "$PSDCONF"
            "$SHAREDIR/browsers/$browser"
          ];
          "${placeholder "out"}/bin/psd-suspend-sync" = true;
          "${placeholder "out"}/bin/profile-sync-daemon" = true;
          "/run/wrappers/bin/fusermount3" = true;
        };
        inputs = deps;
        execer = [
          "cannot:${systemd}/bin/systemd-inhibit"
          "cannot:${systemd}/bin/systemctl"
          "cannot:${fuse3}/bin/fusermount3"
          "cannot:${getent}/bin/getent"
          "cannot:${glib}/bin/gdbus"
          "cannot:${rsync}/bin/rsync"
        ];
      }}

      # $HOME detection fails (and is unnecessary)
      sed -i '/^HOME/d' $out/bin/profile-sync-daemon
    '';

  passthru.tests.simple =
    runCommand "profile-sync-daemon preview"
      {
        nativeBuildInputs = [
          finalAttrs.finalPackage
          writableTmpDirAsHomeHook
        ];
      }
      ''
        # The script tells you to modify your config and to run again.
        profile-sync-daemon preview
        profile-sync-daemon preview

        touch $out
      '';

  meta = {
    description = "Syncs browser profile dirs to RAM";
    longDescription = ''
      Profile-sync-daemon (psd) is a tiny pseudo-daemon designed to manage your
      browser's profile in tmpfs and to periodically sync it back to your
      physical disc (HDD/SSD). This is accomplished via a symlinking step and
      an innovative use of rsync to maintain back-up and synchronization
      between the two. One of the major design goals of psd is a completely
      transparent user experience.
    '';
    homepage = "https://github.com/graysky2/profile-sync-daemon";
    downloadPage = "https://github.com/graysky2/profile-sync-daemon/releases";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.prikhi ];
    platforms = lib.platforms.linux;
  };
})
