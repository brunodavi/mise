#!/usr/bin/env bash
set -euo pipefail

error() {
  echo "$@" >&2
  exit 1
}

RUST_TRIPLE=${1:-$(rustc -vV | grep ^host: | cut -d ' ' -f2)}
#region os/arch
get_os() {
  case "$RUST_TRIPLE" in
    *-apple-darwin*)
      echo "macos"
      ;;
    *-windows-*)
      echo "win"
      ;;
    *-linux-*)
      echo "linux"
      ;;
    *)
      echo "outher"
      ;;
  esac
}

get_arch() {
  case "$RUST_TRIPLE" in
    aarch64-*)
      echo "arm64"
      ;;
    arm*)
      echo "arm"
      ;;
    x86_64-*)
      echo "64bits"
      ;;
    i586-*)
      echo "32bits"
      ;;
    universal2-*)
      echo "universal"
      ;;
    *)
      echo "arch"
      ;;
  esac
}

get_suffix() {
  case "$RUST_TRIPLE" in
    *-android* )
      echo "-android"
      ;;
    *-musl* )
      echo "-musl"
      ;;
    *-gnu* )
      echo "-gnu"
      ;;
    *)
      echo ""
      ;;
  esac
}
#endregion

set -x
os=$(get_os)
arch=$(get_arch)
suffix=$(get_suffix)
version=$(./scripts/get-version.sh)
basename=mise-$version-$os-$arch$suffix

case "$os-$arch" in
  linux-arm*)
    # don't use sccache
    unset RUSTC_WRAPPER
    ;;
esac

if command -v cross >/dev/null; then
  cross build --profile=serious --target "$RUST_TRIPLE" --features openssl/vendored,git2/vendored-libgit2
elif command -v zig >/dev/null; then
  cargo zigbuild --profile=serious --target "$RUST_TRIPLE" --features openssl/vendored,git2/vendored-libgit2
else
  cargo build --profile=serious --target "$RUST_TRIPLE" --features openssl/vendored,git2/vendored-libgit2
fi
mkdir -p dist/mise/bin
mkdir -p dist/mise/man/man1
mkdir -p dist/mise/share/fish/vendor_conf.d
cp "target/$RUST_TRIPLE/serious/mise"* dist/mise/bin
cp README.md dist/mise/README.md
cp LICENSE dist/mise/LICENSE

if [[ "$os" != "win" ]]; then
  cp {,dist/mise/}man/man1/mise.1
  cp {,dist/mise/}share/fish/vendor_conf.d/mise-activate.fish
fi

cd dist

if [[ "$os" == "macos" ]]; then
  codesign -f -s "Developer ID Application: Jeffrey Dickey (4993Y37DX6)" mise/bin/mise
fi

if [[ "$os" == "win" ]]; then
  zip -r "$basename.zip" mise
  ls -oh "$basename.zip"
else
  tar -cJf "$basename.tar.xz" mise
  tar -czf "$basename.tar.gz" mise
  ls -oh "$basename.tar.xz"
fi

mv mise/bin/{mise,mise-$basename}
