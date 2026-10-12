# Changelog

## v0.1.0

First public release for Linux and macOS on amd64 and arm64.

- Validate skill entrypoints, frontmatter policies, local Markdown links, page
  groupings, and tracked-file hygiene. Run explicitly configured repository checks.
- Scan current files and locally available Git history with checksum-pinned
  Gitleaks. Reject shallow clones and target ignore files; repository configuration,
  environment settings, and inline suppression comments cannot disable baseline rules.
- Install and update self-contained consumer bundles with provenance and license
  notices. Refuse modified files, unmanaged files or directories, and symlink
  destinations. Retain recovery backups if rollback fails.
- Fast-forward declared forks, report divergence and missing pins, and optionally
  send webhook notifications. Bound each fork's Git operations with a timeout and
  keep credential-bearing URLs out of webhook errors.
- Reject unknown quality-configuration properties. Reports add
  `contentHashVersion: 2` with unambiguous records for paths, file types, executable
  flags, and content digests. Existing report fields remain present.
- Build with Go 1.26.9, report release/build identity, and publish tested archives
  with checksums. CI covers supported platforms; scheduled security checks and
  dependency-update proposals support maintenance.
