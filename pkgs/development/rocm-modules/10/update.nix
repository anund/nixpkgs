{
  lib,
  writeScript,
}:

{
  finalAttrs ? { },
  name ? finalAttrs.pname,
  owner ? finalAttrs.src.owner,
  repo ? finalAttrs.src.repo,
  page ? "releases?per_page=10",
  tagPrefix ? "rocm|therock",
  prefixSeparator ? "-",
  versionPattern ? "[0-9]+\\\\.[0-9]+(\\\\.[0-9]+)?",
  # Allow a trailing .postN component (e.g. 0.1.29.post1)
  allowPostRelease ? false,
  maxMajor ? 10,
  excludePrereleases ? true,
}:

# Use the following to build an example when debugging:
# nix-build --no-out-link -E '
# let pkgs = import <nixpkgs> { };
# in (builtins.elemAt ((pkgs.callPackage ./update.nix { })
#      { name  = "rocminfo";
#        owner = "ROCm";
#        repo  = "rocm-systems";
#    }) 0)'
let
  pname =
    if lib.hasPrefix "rocm-llvm-" name then "llvm.${lib.removePrefix "rocm-llvm-" name}" else name;

  prefixGroup = if tagPrefix == "" then "" else "(${tagPrefix})${prefixSeparator}";
  postPattern = if allowPostRelease then "(\\\\.post[0-9]+)?" else "";
  tagRegex = "^${prefixGroup}(?<v>${versionPattern}${postPattern})$";
  packageSuffix = lib.optionalString (maxMajor != null) "_" + (toString maxMajor);

  # input: array of [ { tag_name: "rocm-6.x.x", }, ... ]. some entries may have bad names like rocm-test-date we want to skip
  # output: first tag_name/name that's a proper version if any
  filter = lib.concatStringsSep " | " ([
    "if type == \"array\" then . else [.] end"
  ]
  ++ lib.optionals excludePrereleases [
    ". as $all"
    "($all | map(select(.prerelease != true))) as $stable"
    "if ($stable | length) > 0 then $stable else $all end"
  ]
  ++ [
    "map(.tag_name // .name)"
    "map(select(test(\"${tagRegex}\")))"
    "map(capture(\"${tagRegex}\").v)"
  ]
  ++ lib.optionals (maxMajor != null) [
    "map(select((split(\".\")[0] | tonumber) <= ${toString maxMajor}))"
  ]
  ++ [
    # Non-numeric components (e.g. post1, b) sort after the numeric ones of the same base version
    "sort_by(split(\".\") | map(if test(\"^[0-9]+$\") then tonumber else 999999 end))"
    "last // empty"
  ]);

  updateScript = writeScript "update.sh" (''
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p curl jq common-updater-scripts
    set -euo pipefail

    fetch_releases() {
      local api_url="https://api.github.com/repos/${owner}/${repo}/${page}"
      if [ "${page}" = "releases" ]; then
        api_url="$api_url?per_page=4"
      fi
      >&2 echo $api_url
      curl ''${GITHUB_TOKEN:+-u ":$GITHUB_TOKEN"} -sL "$api_url"
    }

    find_valid_version() {
      local releases="$1"
      echo "$releases" | jq -cM >&2
      >&2 echo 'jq -r ${filter}'
      echo "$releases" | jq -r '${filter}'
    }

    releases="$(fetch_releases)"
    version="$(find_valid_version "$releases")"

    if [ -z "$version" ]; then
      echo "No valid version found in the fetched release(s)." >&2
      exit 1
    fi

    IFS='.' read -ra version_arr <<< "$version"

    >&2 echo parsed version "''${version_arr[0]}" from "$version"
  ''
  + lib.optionalString (maxMajor != null) ''
    >&2 echo "''${version_arr[0]}"
    if (( ''${version_arr[0]} > ${toString maxMajor} )); then
      echo "'rocmPackages.${pname}' is already at its maximum allowed version.''\nAny further upgrades should go into 'rocmPackages_${toString (maxMajor + 1)}.${pname}'." >&2
      exit 1
    fi
  ''
  + ''
    update-source-version rocmPackages${packageSuffix}.${pname} "$version" --ignore-same-hash
  '');
in
[ updateScript ]
