# Security

Report suspected vulnerabilities through
[GitHub private vulnerability reporting](https://github.com/tpscloud/skillforge-ci/security/advisories/new).
Include the affected version, operating system, reproduction steps, and expected
and observed behavior. Use synthetic credentials in examples. Do not put live
secrets or sensitive scan reports in public issues.

Security fixes target the latest release. Earlier versions may require an
upgrade. Consumer bundles do not update automatically: after reviewing a fix,
reinstall the bundle with `skillforge install PATH --update` and inspect the diff.

`check` executes commands supplied by a repository with your permissions.
Run it only on repositories you trust. The installed workflow also builds code
from the consumer repository; it is not a sandbox for hostile repositories.

Secret scanning uses pinned Gitleaks rules and rejects incomplete shallow
history. A passing scan does not establish that a repository contains no secrets.
See the README for scan scope and the handling of repository suppression files.
