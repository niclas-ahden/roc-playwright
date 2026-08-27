#!/usr/bin/env bash
# Install Playwright and its browsers, which every test in this repository
# drives. Run by suite.yml's `setup`, once Roc is installed.
#
# Keep the version in step with the dev shell's playwright-test
# (`nix develop -c playwright --version`). We talk to Playwright's private
# driver protocol, which upstream may change in any release, so a runner and a
# developer machine disagreeing about the version means they are testing two
# different protocols.
set -euo pipefail

PLAYWRIGHT_VERSION=1.61.1

npm install -g "playwright@$PLAYWRIGHT_VERSION"

# Only a Linux runner is missing the system libraries the browsers need.
if [ "$RUNNER_OS" = Linux ]; then
  playwright install --with-deps chromium firefox webkit
else
  playwright install chromium firefox webkit
fi

playwright --version
