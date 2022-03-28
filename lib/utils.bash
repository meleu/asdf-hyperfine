#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/sharkdp/hyperfine"
TOOL_NAME="hyperfine"
TOOL_TEST="hyperfine --help"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if hyperfine is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
  list_github_tags
}

get_platform() {
  local platform="$(uname)"
  echo -n "${platform,,}"
}

get_arch() {
  local arch="$(uname -m)"
  echo -n "${arch,,}"
}

download_release() {
  local version="$1"
  local filename="$2"
  local platform="$(get_platform)"
  local arch="$(get_arch)"

  # TODO: is it possible to detect if system is using musl?
  local url="$GH_REPO/releases/download/v${version}/hyperfine-v${version}-${arch}-unknown-${platform}-gnu.tar.gz"

  echo "* Downloading $TOOL_NAME release $version..."

  # TODO: if it fails, show a link to the hyperfine release page
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"

    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH/$tool_cmd" "$install_path"

    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
