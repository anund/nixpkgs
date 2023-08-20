{ lib
, buildPythonPackage
, bootstrapped-pip
, fetchFromGitHub
, mock
, scripttest
, virtualenv
, pretend
, pytest
, installShellFiles

# coupled downsteam dependencies
, pip-tools
}:

buildPythonPackage rec {
  pname = "pip";
  version = "23.0.1";
  format = "other";

  src = fetchFromGitHub {
    owner = "pypa";
    repo = pname;
    rev = "refs/tags/${version}";
    hash = "sha256-BSonlwKmegrlrQTTIL0avPi61/TY2M0f7kOZpSzPRQk=";
    name = "${pname}-${version}-source";
  };

  nativeBuildInputs = [
    bootstrapped-pip
    installShellFiles
  ];

  postPatch = ''
    # Remove vendored Windows PE binaries
    # Note: These are unused but make the package unreproducible.
    find -type f -name '*.exe' -delete
  '';

  # pip detects that we already have bootstrapped_pip "installed", so we need
  # to force it a little.
  pipInstallFlags = [ "--ignore-installed" ];

  nativeCheckInputs = [ mock scripttest virtualenv pretend pytest ];
  # Pip wants pytest, but tests are not distributed
  doCheck = false;

  passthru.tests = { inherit pip-tools; };

  postInstall = ''
    # point pip at it's src
    PYTHONPATH=$src/src

    # note zsh likely won't work until is closed https://github.com/pypa/pip/issues/12166
    # --no-cache-dir avoids a warning about being unable to write to .cache
    installShellCompletion --cmd pip \
      --bash <($out/bin/pip completion --bash --no-cache-dir) \
      --fish <($out/bin/pip completion --fish --no-cache-dir) \
      --zsh <($out/bin/pip completion --zsh --no-cache-dir)
  '';

  meta = {
    description = "The PyPA recommended tool for installing Python packages";
    license = with lib.licenses; [ mit ];
    homepage = "https://pip.pypa.io/";
    changelog = "https://pip.pypa.io/en/stable/news/#v${lib.replaceStrings [ "." ] [ "-" ] version}";
    priority = 10;
  };
}
