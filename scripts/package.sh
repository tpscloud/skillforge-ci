#!/usr/bin/env bash
# Copyright 2026 John Deatherage (@coversheets). SPDX-License-Identifier: MIT
set -euo pipefail
version="${1:?usage: package.sh VERSION OUTPUT_DIRECTORY [GOOS GOARCH]}"
output="${2:?output directory is required}"
target_os="${3:-$(go env GOOS)}"
target_arch="${4:-$(go env GOARCH)}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
  echo 'Version must be a semantic version without a v prefix.' >&2
  exit 2
fi
case "$target_os/$target_arch" in
  linux/amd64|linux/arm64|darwin/amd64|darwin/arm64) ;;
  *) echo 'Unsupported release platform.' >&2; exit 2 ;;
esac
root="$(cd "$(dirname "$0")/.." && pwd -P)"
mkdir -p "$output"
output="$(cd "$output" && pwd -P)"
case "$output/" in "$root/"*) echo 'Keep package output outside the repository.' >&2; exit 2 ;; esac
archive="skillforge_${version}_${target_os}_${target_arch}.tar.gz"
if [[ -e "$output/$archive" ]]; then echo 'Package already exists.' >&2; exit 2; fi
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cd "$root"
CGO_ENABLED=0 GOOS="$target_os" GOARCH="$target_arch" go build -mod=readonly -trimpath -buildvcs=true \
  -ldflags "-X main.version=$version" -o "$stage/skillforge" .
cp LICENSE NOTICE.md README.md "$stage/"
cp -R licenses "$stage/"
COPYFILE_DISABLE=1 tar -czf "$output/$archive" -C "$stage" skillforge LICENSE NOTICE.md README.md licenses
(cd "$output" && shasum -a 256 "$archive" > "$archive.sha256")
printf '%s\n' "$output/$archive"
