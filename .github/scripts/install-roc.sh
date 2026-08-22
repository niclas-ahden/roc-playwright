#!/usr/bin/env bash
# Install a Roc nightly by tag and put it on the PATH of later steps.
#
#   .github/scripts/install-roc.sh nightly-2026-08-20-9e3980a
#
# Needs GH_TOKEN, and the RUNNER_* and GITHUB_PATH variables of a job.
set -euo pipefail

ROC_TAG=${1:?usage: install-roc.sh <nightly-tag>}

# One asset per system. Windows is the only system whose nightly ships as a
# zip rather than a tarball.
case "$RUNNER_OS-$RUNNER_ARCH" in
  Linux-X64)   asset=linux_x86_64        ; archive=tar.gz ;;
  Linux-ARM64) asset=linux_arm64         ; archive=tar.gz ;;
  macOS-ARM64) asset=macos_apple_silicon ; archive=tar.gz ;;
  macOS-X64)   asset=macos_x86_64        ; archive=tar.gz ;;
  Windows-X64) asset=windows_x86_64      ; archive=zip    ;;
  *)
    echo "error: no roc nightly asset for $RUNNER_OS-$RUNNER_ARCH" >&2
    exit 1
    ;;
esac

url=$(gh release view "$ROC_TAG" --repo roc-lang/nightlies --json assets \
        -q ".assets[] | select(.name | test(\"$asset\")) | .url")
[ -n "$url" ] || { echo "error: no $asset asset on $ROC_TAG" >&2; exit 1; }

# RUNNER_TEMP is a backslash path on Windows, which neither this bash nor
# tar's -C reads as one. Forward slashes work in both, and in the PATH entry
# later steps inherit. A no-op everywhere else.
dest="${RUNNER_TEMP//\\//}/roc"
mkdir -p "$dest"

curl -sSL -o "roc_nightly.$archive" "$url"

# Both archives hold a single top-level directory. Do not reach for tar on
# the zip: a Windows runner's bash can resolve `tar` to MSYS's GNU tar, which
# cannot read a zip at all.
if [ "$archive" = zip ]; then
  powershell -NoProfile -NonInteractive -Command \
    "Expand-Archive -LiteralPath 'roc_nightly.zip' -DestinationPath 'roc_nightly_unzipped' -Force"
  mv roc_nightly_unzipped/*/* "$dest"/
  rm -rf roc_nightly_unzipped
else
  tar -xzf "roc_nightly.$archive" --strip-components=1 -C "$dest"
fi
rm "roc_nightly.$archive"

[ -f "$dest/roc" ] || [ -f "$dest/roc.exe" ] || {
  echo "error: no roc binary landed in $dest" >&2
  ls -la "$dest" >&2
  exit 1
}

echo "$dest" >> "$GITHUB_PATH"
"$dest"/roc --version
