#!/usr/bin/env bash
# Copyright 2026 John Deatherage (@coversheets). SPDX-License-Identifier: MIT
set -euo pipefail
binary="$1"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
git init -q "$fixture_dir/repo"
git -C "$fixture_dir/repo" -c user.name=coversheets -c user.email=124883633+coversheets@users.noreply.github.com -c commit.gpgsign=false commit -q --allow-empty -m fixture
"$binary" scan "$fixture_dir/repo" --output-directory "$fixture_dir/clean"
# Synthetic scanner input, assembled only in the temporary repository.
fixture_token="$(openssl rand -hex 18)"
printf 'github_token = "ghp_%s"\n' "$fixture_token" > "$fixture_dir/repo/seed.txt"
set +e
"$binary" scan "$fixture_dir/repo" --output-directory "$fixture_dir/seeded"
result=$?
set -e
if [[ "$result" -ne 1 ]]; then
  echo "Expected a findings exit code, got $result" >&2
  exit 1
fi
git -C "$fixture_dir/repo" add seed.txt
git -C "$fixture_dir/repo" -c user.name=coversheets -c user.email=124883633+coversheets@users.noreply.github.com -c commit.gpgsign=false commit -q -m 'Synthetic scanner fixture'
git -C "$fixture_dir/repo" rm -q seed.txt
git -C "$fixture_dir/repo" -c user.name=coversheets -c user.email=124883633+coversheets@users.noreply.github.com -c commit.gpgsign=false commit -q -m 'Remove synthetic fixture'
set +e
"$binary" scan "$fixture_dir/repo" --output-directory "$fixture_dir/history"
result=$?
set -e
if [[ "$result" -ne 1 ]]; then
  echo "Expected a historical finding, got $result" >&2
  exit 1
fi
echo 'Clean, current-file, and deleted-history scanner checks passed.'
