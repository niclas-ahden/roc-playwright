#!/usr/bin/env bash
set -eo pipefail

cd "$(dirname "$0")"

echo "Building test server..."
rm -f ./test-server
roc build tests/server/main.roc --output ./test-server --linker=legacy
echo "Build complete"
echo

echo "Running Playwright tests in parallel..."

# Use systemd scope when available (ensures all descendant processes are killed)
# Fall back to direct execution in CI where systemd user session isn't available
run_cmd=(roc dev tests/run.roc --linker=legacy -- "$@")
if systemctl --user show-environment &>/dev/null; then
    systemd-run --scope --user "${run_cmd[@]}"
else
    "${run_cmd[@]}"
fi
