# Skillforge maintenance

Keep this repository private unless the owner explicitly requests publication.
Use signed commits with `124883633+coversheets@users.noreply.github.com` and
verify the effective Git identity before committing. Commit and push completed
changes, then check CI at the pushed revision.

Use the installed use-modern-go skill for Go changes and Cobra for the CLI.
The toolkit implementation and CI scripts use Go or Bash. Preserve compatibility
with the documented configuration and evidence formats, and retain dependency
license notices when updating modules.

Run `go test -race ./...`, `go vet ./...`, and the scanner integration script
for changes to scanning. Test failure paths as well as successful checks. A
missing report must never become a passing scan. Bundle updates must preserve
unrelated files and retain backups when rollback fails.

Rebuild and install the updated executable to `~/.local/bin/skillforge` and
verify that binary before reporting completion. Keep build output outside the
repository. Do not migrate consumer repositories without a task that includes
their integration.

Apply humanizer and avoid-ai-writing to authored documentation while preserving
code, commands, links, source notices, and uncertainty.
