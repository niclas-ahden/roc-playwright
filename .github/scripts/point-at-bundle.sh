#!/usr/bin/env bash
# Point every test in the checkout at a package bundle.
#
#   .github/scripts/point-at-bundle.sh https://.../<hash>.tar.zst
#   .github/scripts/point-at-bundle.sh http://127.0.0.1:8788/<hash>.tar.zst
#
# Makes a run test the artifact instead of this checkout's package. The
# localhost form is for draft bundles: roc allows http to localhost, and does
# the download, hash check and unbundle itself either way.
set -euo pipefail

url=${1:?usage: point-at-bundle.sh <bundle-url>}

mapfile -t tests < <(grep -rl '"\.\./\.\./package/main\.roc"' tests --include='*.roc')
[ "${#tests[@]}" -gt 0 ] || {
  echo "error: no test names this checkout's package" >&2
  exit 1
}

for src in "${tests[@]}"; do
  sed -i.bak "s|\"\.\./\.\./package/main\.roc\"|\"$url\"|" "$src"
  rm -f "$src.bak"
done

# A rewrite that silently matched nothing would leave the run testing this
# checkout while reporting that it tested the bundle.
leftover=$(grep -rl 'package/main\.roc"' tests --include='*.roc' || true)
[ -z "$leftover" ] || {
  echo "error: these tests still name this checkout's package" >&2
  echo "$leftover" >&2
  exit 1
}

echo "rewrote ${#tests[@]} tests to $url"
