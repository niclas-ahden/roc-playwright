#!/usr/bin/env bash
# Name the Playwright version a release was tested with in its notes.
#
#   .github/scripts/name-playwright.sh <release-tag> <playwright-version>
#
# Needs GH_TOKEN and GITHUB_REPOSITORY in the environment.
#
# The release flow runs this once the draft exists. The version comes from
# setup.sh at the released tag, which is the version every suite leg in the
# run installs, so the notes name exactly what was tested. Unlike the Roc
# line, which the daily workflow keeps moving forward, this line never moves:
# the pin is part of the release.
#
# The "Tested with:" line is machine owned and replaced outright. The rest of
# the section is written once and then left alone, so an edit someone made to
# the draft survives a re-run.
set -euo pipefail

release=${1:?usage: name-playwright.sh <release-tag> <playwright-version>}
version=${2:?usage: name-playwright.sh <release-tag> <playwright-version>}

notes=$(mktemp)
trap 'rm -f "$notes" "$notes.bak" "$notes.new"' EXIT
gh release view "$release" --json body -q .body --repo "$GITHUB_REPOSITORY" > "$notes"

# shellcheck disable=SC2016  # the backticks are markdown, not a subshell
current=$(sed -n 's|^Tested with: \[`playwright@\([^`]*\)`\].*|\1|p' "$notes" | head -1)

if [ "$current" = "$version" ]; then
  echo "$release notes already name playwright@$version"
  exit 0
fi

line="Tested with: [\`playwright@$version\`](https://github.com/microsoft/playwright/releases/tag/v$version)."

if grep -q '^Tested with: ' "$notes"; then
  sed -i.bak "s|^Tested with: .*|$line|" "$notes"
else
  section="## Playwright version

$line

We talk to Playwright's private driver protocol, which upstream may change in any release. Other versions are untested, so if something misbehaves, try the version above first."

  # Between the compiler section and the usage snippet when both are there,
  # at the end otherwise.
  awk -v section="$section" '
    !done && /^## Using this release/ { print section; print ""; done = 1 }
    { print }
    END { if (!done) { print ""; print section } }
  ' "$notes" > "$notes.new"
  mv "$notes.new" "$notes"
fi

gh release edit "$release" --notes-file "$notes" --repo "$GITHUB_REPOSITORY"
if [ -n "$current" ]; then
  echo "$release now names playwright@$version (was $current)"
else
  echo "$release now names playwright@$version"
fi
