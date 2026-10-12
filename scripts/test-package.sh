#!/usr/bin/env bash
# Copyright 2026 John Deatherage (@coversheets). SPDX-License-Identifier: MIT
set -euo pipefail
archive="${1:?usage: test-package.sh ARCHIVE VERSION}"
version="${2:?version is required}"
archive="$(cd "$(dirname "$archive")" && pwd -P)/$(basename "$archive")"
(cd "$(dirname "$archive")" && shasum -a 256 -c "$(basename "$archive").sha256")
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/package" "$work/repo"
tar -xzf "$archive" -C "$work/package"
binary="$work/package/skillforge"
"$binary" --version | grep -F "skillforge version $version (revision "
"$binary" --help > /dev/null
for notice in LICENSE NOTICE.md licenses/GO.txt licenses/COBRA.txt licenses/PFLAG.txt licenses/GOLDMARK.txt licenses/YAML.txt licenses/MOUSETRAP.txt licenses/GITLEAKS.txt; do
  test -s "$work/package/$notice"
done
git init -q "$work/repo"
printf '%s\n' '---' 'name: fixture' 'description: Exercise an installed release bundle.' '---' 'Fixture.' > "$work/repo/SKILL.md"
printf '%s\n' '{"groupings":[{"title":"Fixture","skills":["fixture"]}]}' > "$work/repo/skills.sh.json"
"$binary" install "$work/repo"
"$binary" validate "$work/repo" --output "$work/report.json"
"$binary" check "$work/repo"
"$binary" install "$work/repo" --update
go -C "$work/repo/.skill-quality" build -mod=readonly -trimpath -o "$work/rebuilt" .
"$work/rebuilt" validate "$work/repo" > /dev/null
# Modified managed files must survive an attempted update unchanged.
printf '\n// local change\n' >> "$work/repo/.skill-quality/main.go"
cp "$work/repo/.skill-quality/main.go" "$work/expected.go"
if "$binary" install "$work/repo" --update; then
  echo 'A package update overwrote local changes.' >&2
  exit 1
fi
cmp "$work/expected.go" "$work/repo/.skill-quality/main.go"
echo 'Packaged executable and consumer bundle verified.'
