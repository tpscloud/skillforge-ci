# Contributing

Use Go 1.26.9 or later, Git, and Bash on Linux or macOS. Tests use temporary
repositories and local HTTP servers. Scanner integration tests download a
checksum-pinned Gitleaks release from GitHub.

Before submitting a change, run:

```bash
gofmt -w ./*.go
go mod verify
go vet ./...
go test -race ./...
go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12 .github/workflows/*.yml templates/*.yml
work="$(mktemp -d)"
go build -mod=readonly -trimpath -o "$work/skillforge" .
bash scripts/test-scanner.sh "$work/skillforge"
bash scripts/package.sh 0.0.0-dev "$work/packages"
bash scripts/test-package.sh "$work/packages/skillforge_0.0.0-dev_$(go env GOOS)_$(go env GOARCH).tar.gz" 0.0.0-dev
```

Keep build output outside the checkout. Tests must cover failure paths for
changes to scanning, configuration, evidence, installation, or fork operations.
A missing report must remain an error. Bundle updates must preserve local files
and recovery backups. Preserve existing configuration and report fields; document
new fields and version changes. Dependency updates must also update NOTICE.md
and retain the corresponding license texts.

Submit changes through a pull request. The `CI required` and `Security required`
checks must pass before merging. Dependabot proposes Go-module and Actions
updates weekly. Review the pinned Go patch version, Gitleaks version/digests,
and command-line tools in workflows separately; those are not all module
requirements that Dependabot can update.

## Releasing

Release binaries cover Linux and macOS on amd64 and arm64. The tag workflow
reruns CI and security checks, verifies each archive on its native runner, then
publishes those tested archives and `checksums.txt`. A failed job prevents
publication. A failed upload can leave a draft release; rerunning replaces only
draft assets and refuses to overwrite a published release.

From a clean, tested `main` checkout:

1. Update CHANGELOG.md and the installation example for the version being released.
2. Verify the maintainer Git identity and create a signed release-preparation
   commit. Push it through the required checks.
3. Create and push a signed tag, for example:

   ```bash
   git tag -s v0.1.0 -m 'Skillforge v0.1.0'
   git push origin v0.1.0
   ```

4. Check the Release workflow at that exact tag. Download the native archive and
   checksums from the published release and run `scripts/test-package.sh` against
   it. That script expects an adjacent `ARCHIVE.sha256` file; obtain it by selecting
   the archive's line from `checksums.txt`.
5. Install the verified executable to `~/.local/bin/skillforge` and check
   `skillforge --version` and an isolated consumer-bundle installation.

The archive includes dependency notices. Consumer repositories adopt releases
through a separate reviewed bundle update; publishing a release does not modify
their copies. Local release builds use `scripts/package.sh VERSION OUTPUT_DIR`
and embed the version through Go linker flags. Ordinary source builds show `dev`.
