# Security Policy

## Scope

This project is a shell script that runs locally as a Claude Code status line generator. It reads from stdin (JSON piped by Claude Code) and local config files.

## What this script accesses

- **stdin**: JSON from Claude Code (session info, cost, model)
- **`~/.claude/settings.json`**: Read-only, for effort level
- **`~/.claude/cost_tracking.json`**: Read/write, for cost history (cost tracking variant only)
- **`git`**: Local git commands for branch/status info

## What this script does NOT do

- Make any network requests
- Access credentials, tokens, or secrets
- Modify files outside `~/.claude/cost_tracking.json`
- Execute arbitrary commands from the input JSON
- Send data to external servers

## Reporting a vulnerability

Please report security issues via [GitHub private vulnerability reporting](https://github.com/eris-ths/claude-code-statusline/security/advisories/new) rather than public issues, to avoid disclosing vulnerabilities before a fix is available.
