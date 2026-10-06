# Skillforge CI

Skillforge checks agent skill repositories from a local Go executable. It
validates declared entrypoints, runs configured tests, and scans Git history
and current files for secrets. The toolkit uses Go and Bash, with no Python
runtime dependency.

This repository is private. Existing one-skill consumers have not been migrated.

## Build and use

Requires Go 1.26.8 or later and Git on Linux or macOS. The first build downloads
the Go modules pinned in go.mod and go.sum.

```bash
go test -race ./...
go build -mod=readonly -trimpath -o ~/.local/bin/skillforge .
skillforge --help

skillforge validate /path/to/skill-repo --output /tmp/quality-report.json
skillforge check /path/to/skill-repo
skillforge scan /path/to/skill-repo --output-directory /tmp/new-scan-directory
```

`validate` reads `.skill-quality.json` and `skills.sh.json`. It checks YAML
frontmatter, local Markdown links in entrypoint prose, page groupings, tracked
symlinks, and generated-file hygiene. Links in code examples are ignored.
Reports include the Git revision, dirty state, repository content hash, toolkit
source hash, findings, and the checks that were not performed. A missing Git
repository or malformed configuration produces a failure report.

`check` runs the argument arrays declared in `.skill-quality.json`, from their
repository-relative working directories. Each check has a ten-minute timeout;
cancellation also stops child processes. Only run this command on repositories
whose configured commands you trust. It executes repository code with your
permissions. Validation alone does not execute those commands.

`scan` downloads Gitleaks v8.30.1 from its official GitHub release, verifies a
pinned SHA-256 digest, then runs both the all-refs history scan and the current
directory scan. It supports arm64 and amd64 on Linux and macOS. Reports are
redacted and stay in a newly created directory outside the scanned repository.
Missing reports, scanner errors, and results that disagree with the scanner's
exit code are failures. The summary records each mode separately. CI uploads
only the summary; detailed findings remain local to the runner.

Exit status is `0` for success, `1` for validation or secret findings, and `2`
for operational errors, invalid commands, or failed configured tests. A passing
result does not establish model behavior, licensing rights, installer
compatibility, or approval from an external security service.

## Install a consumer bundle

```bash
skillforge install /path/to/skill-repo
# After reviewing an existing managed bundle:
skillforge install /path/to/skill-repo --update
```

The installer copies its embedded sources, pinned module files, license texts,
tests, and provenance into `.skill-quality/`, and adds the GitHub Actions
workflow `.github/workflows/skill-quality.yml`. Consumers build from that copy
without access to this private repository. The manifest records the producer
revision and dirty state, content hash, and individual file digests. Copies
retain the producer provenance when built and installed elsewhere. Edits to
the copied sources mark that provenance dirty on the next installation.

Existing `.skill-quality.json` files are preserved. When that file is absent,
the installer inventories tracked and unignored `SKILL.md` files and creates
an empty check list. Review the inventory, including any intentional plugin
copies. The installer does not create `skills.sh.json`.

Updates accept recognized Skillforge bundles and the version-1 one-skill
bundle. They check the previous manifest before replacing files and refuse
modified managed files, unrecognized files, or symlink destinations. Legacy
Python helpers and their requirements are removed as part of a successful
replacement. A failed replacement restores the old files. If restoration also
fails, the recovery directory is retained and its path appears in the error.

Repository-specific tests keep their existing commands and dependencies. Before
migrating a consumer, add any required test-language setup to a separate
repository workflow or provide it through the declared checks. The supplied
workflow installs only Go; it does not provision Python or Node for consumer
tests. Migration of the existing skill repositories is deferred.

## Configuration

The existing `.skill-quality.json` format is supported:

```json
{
  "version": 1,
  "skills": ["skills/example/SKILL.md"],
  "checks": [
    {
      "name": "Go tests",
      "command": ["go", "test", "./..."],
      "cwd": "."
    }
  ]
}
```

Page configuration supports `groupings`, `notGrouped`, `$schema`, and the legacy
`schema` field. Groupings require a title and skill-name array, and may include
a description. Duplicate JSON keys, duplicate grouping entries, and unknown
page properties fail validation. Ungrouped declared skills produce warnings.
These checks implement the supported fields locally; no third-party schema is
bundled or fetched at validation time.

## Verification and licensing

`go test -race ./...` covers malformed input, path escapes, symlinks, command
cancellation, scanner failures and missing evidence, isolated bundle builds,
legacy updates, preservation of local work, and recovery after two consecutive
rename failures. `scripts/test-scanner.sh` exercises the actual downloaded
scanner against a clean repository and a synthetic finding. CI runs on Linux
and macOS, then scans this repository.

Original code, documentation, and workflow templates use [MIT](LICENSE).
[NOTICE.md](NOTICE.md) identifies dependency versions and their bundled license
texts. Gitleaks is downloaded separately and retains its own license.
