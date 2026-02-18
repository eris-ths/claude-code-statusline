# Security Policy

## Scope

This project is a shell script that runs locally on your machine as a Claude Code status line generator. It reads from stdin (JSON piped by Claude Code) and local files (`~/.claude/settings.json`, cost tracking file).

## What this script accesses

- **stdin**: JSON from Claude Code (session info, cost, model)
- **`~/.claude/settings.json`**: Read-only, for effort level
- **`~/.claude/cost_tracking.json`**: Read/write, for cost history (cost tracking variant only)
- **`git`**: Local git commands for branch/status info
- **No network access**: This script makes no outbound network requests

## What this script does NOT do

- Send any data to external servers
- Access credentials, tokens, or secrets
- Modify any files outside `~/.claude/cost_tracking.json`
- Execute arbitrary commands from the input JSON

## Reporting a vulnerability

If you find a security issue, please open a GitHub issue or contact via the repository.
