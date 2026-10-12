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
# Exercise each suppression separately so one cannot mask a broken boundary.
sed -n 's/.*"Fingerprint": "\(.*\)".*/\1/p' "$fixture_dir/seeded/gitleaks-dir.json" > "$fixture_dir/fingerprints"
test -s "$fixture_dir/fingerprints"
cat > "$fixture_dir/suppress.toml" <<'EOF'
[extend]
useDefault = true
[allowlist]
paths = ['.*']
EOF
for suppression in repository environment ignore inline; do
  cp "$fixture_dir/repo/seed.txt" "$fixture_dir/seed-backup"
  case "$suppression" in
    repository) cp "$fixture_dir/suppress.toml" "$fixture_dir/repo/.gitleaks.toml" ;;
    environment) export GITLEAKS_CONFIG="$fixture_dir/suppress.toml" GITLEAKS_CONFIG_TOML='invalid toml' ;;
    ignore) cp "$fixture_dir/fingerprints" "$fixture_dir/repo/.gitleaksignore" ;;
    inline) sed 's/$/ # gitleaks:allow/' "$fixture_dir/seed-backup" > "$fixture_dir/repo/seed.txt" ;;
  esac
  set +e
  "$binary" scan "$fixture_dir/repo" --output-directory "$fixture_dir/suppression-$suppression"
  result=$?
  set -e
  expected=1
  if [[ "$suppression" == ignore ]]; then expected=2; fi
  if [[ "$result" -ne "$expected" ]]; then
    echo "$suppression suppression: expected $expected, got $result" >&2
    exit 1
  fi
  unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML
  rm -f "$fixture_dir/repo/.gitleaks.toml" "$fixture_dir/repo/.gitleaksignore"
  cp "$fixture_dir/seed-backup" "$fixture_dir/repo/seed.txt"
done
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
echo 'Clean, current-file, suppression, and deleted-history scanner checks passed.'
