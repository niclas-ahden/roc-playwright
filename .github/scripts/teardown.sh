#!/usr/bin/env bash
# Prove that nothing Playwright started is still alive. Run by suite.yml's
# `teardown`, once the tests have passed.
set -euo pipefail

# The runner started with no Playwright process and no test server, so
# anything of ours alive now was left behind by the suite. `none` is the
# absolute form, which only holds on a machine that started clean.
roc tests/leak/check.roc -- none

# Every browser, every way a program can end. Red here means a user of the
# package is left with browsers running after their program is gone.
roc tests/leak/check.roc
