#!/usr/bin/env bash
# Prints the next release tag (vX.Y.Z) derived from the conventional commits
# since the latest release, or nothing when no commit warrants a release:
#   type!: ... or "BREAKING CHANGE:" in a body -> major
#   feat: ...                                  -> minor
#   fix: ... / perf: ...                       -> patch
set -euo pipefail

# The fork carries no tags of its own until its first release, so it starts
# from the upstream release it was last synced with.
BASELINE_TAG="${BASELINE_TAG:-v1.10.1}"
BASELINE_COMMIT="${BASELINE_COMMIT:-c196856d221b7209debef3f8c9b46f2a6ca81233}"

if last_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' HEAD 2>/dev/null); then
  since="$last_tag"
else
  last_tag="$BASELINE_TAG"
  since="$BASELINE_COMMIT"
fi

subjects=$(git log --format=%s "$since..HEAD")
bodies=$(git log --format=%b "$since..HEAD")

if grep -qE '^[a-z]+(\([^)]*\))?!:' <<<"$subjects" || grep -qE '^BREAKING[ -]CHANGE:' <<<"$bodies"; then
  bump=major
elif grep -qE '^feat(\([^)]*\))?:' <<<"$subjects"; then
  bump=minor
elif grep -qE '^(fix|perf)(\([^)]*\))?:' <<<"$subjects"; then
  bump=patch
else
  exit 0
fi

IFS=. read -r major minor patch <<<"${last_tag#v}"
case "$bump" in
  major) echo "v$((major + 1)).0.0" ;;
  minor) echo "v${major}.$((minor + 1)).0" ;;
  patch) echo "v${major}.${minor}.$((patch + 1))" ;;
esac
