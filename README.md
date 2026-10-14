# Skillforge CI

[![CI](https://github.com/tpscloud/skillforge-ci/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/tpscloud/skillforge-ci/actions/workflows/ci.yml)
[![Security](https://github.com/tpscloud/skillforge-ci/actions/workflows/security.yml/badge.svg?branch=main)](https://github.com/tpscloud/skillforge-ci/actions/workflows/security.yml)
[![Release](https://img.shields.io/github/v/release/tpscloud/skillforge-ci)](https://github.com/tpscloud/skillforge-ci/releases/latest)
[![Go version](https://img.shields.io/github/go-mod/go-version/tpscloud/skillforge-ci)](go.mod)
[![MIT license](https://img.shields.io/github/license/tpscloud/skillforge-ci)](LICENSE)

Skillforge checks agent skill repositories from a local Go executable. It
validates declared entrypoints, runs configured tests, and scans Git history
and current files for secrets. It can also fast-forward declared forks to their
upstream branch and report the result. The toolkit uses Go and Bash.

Consumer repositories build from bundles installed by this toolkit. Their CI
runs use the copied source and pinned modules, so adopting a new Skillforge
release is an explicit bundle update.

## Install a release

Download the archive for your operating system and architecture from
[GitHub Releases](https://github.com/tpscloud/skillforge-ci/releases/latest),
along with `checksums.txt`. Releases support Linux and macOS on amd64 and arm64.
Windows is not supported. Git is required at runtime; consumer CI builds also
require Go.

For example, after downloading the macOS arm64 archive for v0.1.0:

```bash
grep 'skillforge_0.1.0_darwin_arm64.tar.gz$' checksums.txt | shasum -a 256 -c -
tar -xzf skillforge_0.1.0_darwin_arm64.tar.gz
mkdir -p ~/.local/bin
install -m 0755 skillforge ~/.local/bin/skillforge
~/.local/bin/skillforge --version
```

Keep the included license notices when redistributing the executable. Add
`~/.local/bin` to your `PATH` if it is not already there. `--version` identifies
the release, source revision, and whether the build used a modified checkout.
Source builds without a release version identify themselves as `dev`.

## Build and use

Requires Go 1.26.9 or later and Git on Linux or macOS. The first build downloads
the Go modules pinned in go.mod and go.sum.

```bash
go test -race ./...
mkdir -p ~/.local/bin
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

Reports retain envelope version 1 and include `contentHashVersion: 2`. This
hash frames each path, file type, executable flag, and content digest separately.
A report without `contentHashVersion` uses the older algorithm; compare hashes
only when their algorithm versions match. Tracked submodules and other special
file types fail hashing rather than producing incomplete evidence.

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
exit code are failures. The summary records each mode separately and names the scan policy. The baseline uses the pinned scanner's built-in rules and ignores target `.gitleaks.toml`, inline `gitleaks:allow` comments, and environment configuration overrides. Gitleaks also loads a target `.gitleaksignore` even with an explicit ignore path, so Skillforge refuses targets containing that file. Review it and scan a separate copy without it; the original checkout is left intact. Review false positives in the evidence; target-controlled suppressions cannot turn this baseline green. CI uploads
only the summary; detailed findings remain local to the runner.

History scanning requires a complete clone. Shallow clones fail with an error
summary; use `git fetch --unshallow` before retrying. The history scan covers all
locally available refs. It does not fetch remote branches or inspect unreachable
objects. GitHub Actions workflows use `fetch-depth: 0`.

Exit status is `0` for success, `1` for validation or secret findings, and `2`
for operational errors, invalid commands, or failed configured tests.
`fork-sync` follows the same convention. A passing
result does not establish model behavior, licensing rights, installer
compatibility, or approval from an external security service.

## Install a consumer bundle

```bash
skillforge install /path/to/skill-repo
# After reviewing an existing managed bundle:
skillforge install /path/to/skill-repo --update
# For repositories that use only skills.sh and Tessl in CI:
skillforge install /path/to/skill-repo --workflow-profile providers
```

The installer copies its embedded sources, pinned module files, license texts,
tests, and provenance into `.skill-quality/`, and adds the GitHub Actions
workflow `.github/workflows/skill-quality.yml`. Consumers build from that copy
without fetching this repository. The manifest records the producer
revision and dirty state, content hash, and individual file digests. Copies
retain the producer provenance when built and installed elsewhere. Edits to
the copied sources mark that provenance dirty on the next installation.

The default `standard` workflow builds Skillforge and runs validation, configured
checks, and the secret scanner. The `providers` workflow tests installation with
the pinned Skills CLI in a temporary project and runs `tessl plugin lint`. It
also runs hosted Tessl quality reviews on the default branch when the
`TESSL_TOKEN` secret and `TESSL_WORKSPACE` variable are configured, failing scores
below 80. Pull requests never receive the review token. Missing credentials or
a non-default branch are reported as reviews not run, not passing reviews.
Neither profile publishes anything.

The provider workflow does not claim hosted skills.sh security coverage. Those
audits are separate from CLI installation and may be unavailable for private
repositories. Local Skillforge commands remain available with either profile.
Updates preserve the installed profile unless `--workflow-profile` explicitly
selects another one.

Existing `.skill-quality.json` files are preserved. When that file is absent,
the installer inventories tracked and unignored `SKILL.md` files and creates
an empty check list. Review the inventory, including any intentional plugin
copies. The installer does not create `skills.sh.json`.

Updates accept recognized Skillforge bundles and the version-1 one-skill
bundle. They check the previous manifest before replacing files and refuse
modified managed files, unrecognized files or directories, or symlink destinations. Legacy
Python helpers and their requirements are removed as part of a successful
replacement. A failed replacement restores the old files. If restoration also
fails, the recovery directory is retained and its path appears in the error.

Repository-specific tests keep their existing commands and dependencies. Before
migrating a consumer, add any required test-language setup to a separate
repository workflow or provide it through the declared checks. The supplied
standard workflow installs only Go; it does not provision Python or Node for consumer
tests.

## Sync forks

```bash
skillforge fork-sync /path/to/directory --check
skillforge fork-sync /path/to/directory --output /tmp/fork-sync.json
```

`fork-sync` reads `.skill-forks.json` from the directory:

```json
{
  "version": 1,
  "forks": [
    {
      "fork": "example-owner/project",
      "upstream": "example-upstream/project",
      "branch": "main",
      "pin": "0123abc"
    }
  ]
}
```

Each entry names a fork, its upstream, and one branch that has the same name
in both. `pin` is an optional commit ID. Unknown keys, duplicate keys, URLs,
and names that begin with a hyphen are rejected before any network access.
This file is separate from `.skill-quality.json`, so `validate` and existing
consumer configurations behave as before.

For each entry the command fetches the branch from both repositories into a
temporary repository and compares them. It pushes the upstream commit to the
fork only when the fork has no commits of its own. The push is never forced,
so the remote also refuses anything other than a fast-forward. After a push
the command reads the fork again and reports `synced` only when the branch is
at the upstream commit. `--check` compares without pushing.

| Status | Meaning | Exit |
| --- | --- | --- |
| `current` | The fork matches upstream. | 0 |
| `synced` | The fork was behind, was fast-forwarded, and was read back at the upstream commit. | 0 |
| `behind` | `--check` found the fork behind. | 1 |
| `diverged` | The fork has commits that upstream lacks. It was not changed. | 1 |
| `pin-missing` | The fork branch does not contain the pinned commit. | 1 |
| `token-insufficient` | The remote refused the read or the push for lack of permission. | 2 |
| `missing` | The fork or branch was not found, or the token cannot see it. | 2 |
| `failed` | Any other error, including a push that could not be confirmed. | 2 |

Each fork has a ten-minute deadline covering its Git operations. Override it
with `--timeout`, for example `--timeout 2m`. A timeout stops the Git process
group and records a failure before continuing with the next fork.

One failing fork does not stop the others. The run exits with the highest
code any fork produced. When `pin` is set, the report also records how many
commits upstream has moved past it. The error texts that select
`token-insufficient` and `missing` come from Git and GitHub messages; text
that matches neither is reported as `failed`.

### Notification

Every run prints one line per fork and writes the JSON report named by
`--output`. In GitHub Actions it also appends a table to the job summary
through `GITHUB_STEP_SUMMARY`. A non-zero exit fails the job, and GitHub then
notifies according to your Actions notification settings. For a scheduled
workflow GitHub documents that the notice goes to the person who last edited
the schedule.

A successful sync exits 0, so GitHub sends no email for it. To hear about
those runs as well, set `SKILLFORGE_NOTIFY_WEBHOOK` to an HTTP or HTTPS URL.
The command posts JSON with a `text` field and the full `report` whenever any
fork is in a state other than `current`. The run exits 2 when the webhook
cannot be reached or answers outside the 2xx range, or when the job summary
cannot be written. Redirects fail delivery. Transport errors are sanitized so
credential-bearing URLs do not reach messages or reports. The command assumes no particular chat or paging service, and
some services require a different payload shape.

### Token

Local runs without `SKILLFORGE_FORK_TOKEN` use your existing Git credentials.
In GitHub Actions the default `GITHUB_TOKEN` cannot do this job. It is limited
to the repository that runs the workflow, and it cannot push commits that
change files under `.github/workflows`. Upstream history usually contains such
commits. Create one of these and store it as the `SKILLFORGE_FORK_TOKEN`
secret:

- A fine-grained personal access token with repository access limited to the
  listed forks, `Contents: Read and write`, and `Workflows: Read and write`.
  GitHub adds `Metadata: Read-only` itself.
- A classic personal access token with the `repo` and `workflow` scopes.
  `public_repo` can replace `repo` when every fork is public.

The token reaches Git through the environment as a header for the
`--git-base` host. It is sent only over HTTPS and only for fork operations.
Upstream is fetched without it, so in CI each upstream must be public. A
missing or refused token produces `token-insufficient` with the required
permissions in the message, and the run exits 2.

### Scheduled workflow

`templates/fork-sync.yml` runs the command daily and on manual dispatch, then
uploads the report. `skillforge install` copies the template to
`.skill-quality/templates/` and does not enable it. Copy it to
`.github/workflows/fork-sync.yml` in the one repository that holds
`.skill-forks.json`, then add the secrets. GitHub can disable scheduled
workflows in a public repository after 60 days without repository activity.

## Configuration

The existing `.skill-quality.json` format is supported. Unknown properties at
the top level or inside a check are rejected, including misspelled keys.
Omitted `version` retains legacy compatibility; explicit version 1 is preferred:

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

Repositories with stricter frontmatter rules can opt in through
`.skill-quality.json`:

```json
"frontmatter": {
  "allowedKeys": ["name", "description", "license", "argument-hint"],
  "requireDirectoryName": true
}
```

`allowedKeys` rejects other top-level YAML fields. If supplied, it must be a
nonempty array of unique, nonempty strings. `requireDirectoryName` requires
each skill's name to match its immediate parent directory, including entrypoints
at the repository root. Both checks are optional; omitting `frontmatter`
preserves the existing behavior. Invalid policy fields fail configuration
validation. The required name and description checks always apply.

## Verification and licensing

`go test -race ./...` covers malformed input, path escapes, symlinks, command
cancellation, scanner failures and missing evidence, isolated bundle builds,
legacy updates, preservation of local work, and recovery after two consecutive
rename failures. The fork sync tests push between local bare repositories and
post to a local HTTP server. They cover a fork that is behind, current,
diverged, or missing, a push refused for a missing workflow permission, and
failed notification delivery. No test contacts GitHub, and the command has not
been run with a token against a GitHub fork. `scripts/test-scanner.sh` exercises the actual downloaded
scanner against clean files, synthetic findings in current files and deleted
history, suppression attempts, and shallow clones. CI tests and verifies release
archives on Linux and macOS, on both amd64 and arm64. The Security workflow checks Go vulnerabilities and scans this repository
on changes and weekly. Coverage profiles are retained as CI artifacts.

Original code, documentation, and workflow templates use [MIT](LICENSE).
[NOTICE.md](NOTICE.md) identifies dependency versions and their bundled license
texts. Gitleaks is downloaded separately and retains its own license.


## Contributing and releases

See [CONTRIBUTING.md](CONTRIBUTING.md) for development checks and the release
procedure, [CHANGELOG.md](CHANGELOG.md) for changes, and [SECURITY.md](SECURITY.md)
for private vulnerability reporting.
