#!/usr/bin/env bash
# Copyright 2026 John Deatherage (@coversheets). SPDX-License-Identifier: MIT
set -euo pipefail

repo="$(cd "${1:?Supply the repository path}" && pwd)"
project="$(mktemp -d)"
trap 'rm -rf "$project"' EXIT
export DISABLE_TELEMETRY=1 DO_NOT_TRACK=1

# A failed discovery or an empty installation must not look like a pass.
jq -e '.skills | type == "array" and length > 0' "$repo/.skill-quality.json" >/dev/null
jq -r '.skills[]' "$repo/.skill-quality.json" > "$project/entrypoints"
npx --yes skills@1.7.2 add "$repo" --list
cd "$project"
npx --yes skills@1.7.2 add "$repo" --agent codex --skill '*' --copy --yes
while IFS= read -r entrypoint; do
  skill="$(basename "$(dirname "$entrypoint")")"
  installed="$project/.agents/skills/$skill/SKILL.md"
  if [[ ! -f "$installed" ]]; then
    printf 'Missing installed skill: %s\n' "$skill" >&2
    exit 1
  fi
  cmp "$repo/$entrypoint" "$installed"
done < "$project/entrypoints"
