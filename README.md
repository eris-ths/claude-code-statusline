# Claude Code Enhanced Status Line

A drop-in status line script for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows essential session info at a glance.

```
⏰14:30 my-project | 🌿main 📝5 | 💰$1.05 | 🤖Opus 4.6 [high]
```

## What it shows

| Section | Description |
|---------|------------|
| `⏰14:30` | Current time |
| `my-project` | Working directory name |
| `🌿main` | Current git branch |
| `📝5` | Number of changed files (hidden when 0) |
| `💰$1.05` | Session cost in USD |
| `🔴200k+` | Token overflow warning (hidden when under limit) |
| `🤖Opus 4.6 [high]` | Current model and effort level |

## Setup

```bash
mkdir -p ~/.claude/scripts
curl -o ~/.claude/scripts/status_line_generator.sh \
  https://raw.githubusercontent.com/eris-ths/claude-code-statusline/main/status_line_generator.sh
chmod +x ~/.claude/scripts/status_line_generator.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "script": "~/.claude/scripts/status_line_generator.sh"
  }
}
```

The status line will appear once Claude Code refreshes (typically within seconds).

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v2.1+
- `jq` (JSON parsing)
- `git` (optional — for branch/status info)

## How it works

Claude Code pipes a JSON object to the status line script via stdin on each refresh. The script extracts:

| Data | Source | Path | Used by |
|------|--------|------|---------|
| Model name | stdin JSON | `.model.display_name` | base, extended |
| Session cost | stdin JSON | `.cost.total_cost_usd` | base, extended |
| Session ID | stdin JSON | `.session_id` | extended only |
| Token overflow | stdin JSON | `.exceeds_200k_tokens` | base, extended |
| Context usage | stdin JSON | `.context_window.used_percentage` | *(available, not displayed)* |
| Effort level | `~/.claude/settings.json` | `.effortLevel` | base, extended |
| Git branch/status | local `git` commands | — | base, extended |

### Status line input JSON

```json
{
  "session_id": "...",
  "model": { "id": "claude-opus-4-6", "display_name": "Opus 4.6" },
  "cost": { "total_cost_usd": 1.05, "total_duration_ms": 316404 },
  "context_window": { "used_percentage": 31, "remaining_percentage": 69 },
  "exceeds_200k_tokens": false,
  "cwd": "/path/to/project",
  "version": "2.1.45"
}
```

### Why effort level comes from settings.json

`effortLevel` is **not** included in the status line input JSON (as of Claude Code v2.1). The script reads it from `~/.claude/settings.json` as a workaround. When effort is set to "high" (the default), Claude Code removes the key entirely — so the script falls back to `"high"`.

## Extended: cost tracking across sessions

The base script shows only the current session's cost. For daily/weekly cumulative tracking:

```bash
curl -o ~/.claude/scripts/status_line_generator.sh \
  https://raw.githubusercontent.com/eris-ths/claude-code-statusline/main/examples/with_cost_tracking.sh
chmod +x ~/.claude/scripts/status_line_generator.sh
```

```
⏰14:30 my-project | 🌿main 📝5 | 💰$1.05 (D:$3/W:$15) | 🤖Opus 4.6 [high]
```

### Currency conversion

```bash
# Add to your shell profile (.zshrc, .bashrc, etc.)
export CLAUDE_CURRENCY_RATE=146.87   # USD → JPY
export CLAUDE_CURRENCY_SYMBOL=¥
```

```
⏰14:30 my-project | 🌿main 📝5 | 💰¥154 (D:¥470/W:¥2261) | 🤖Opus 4.6 [high]
```

### Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `CLAUDE_COST_FILE` | `~/.claude/cost_tracking.json` | Cost tracking file path |
| `CLAUDE_CURRENCY_RATE` | `1` | Conversion rate from USD |
| `CLAUDE_CURRENCY_SYMBOL` | `$` | Currency symbol |
| `CLAUDE_COST_PURGE_DAYS` | `30` | Auto-purge sessions older than N days |

## Customization ideas

Fork this script and make it yours. Some ideas:

- **Context bar** — show `context_window.used_percentage` as `[████░░░░░░] 40%`
- **Elapsed time** — replace clock with session duration using `.cost.total_duration_ms`
- **Compact mode** — show only cost + model when terminal is narrow
- **Color** — use ANSI escape codes for cost thresholds (green < $1, yellow < $5, red). Note: ANSI support depends on your terminal and Claude Code version

## Design principles

- **Never fail** — A status line that crashes is worse than one with partial info. All side effects (cost tracking, file I/O) are guarded with `|| true`. Display always proceeds.
- **No `set -e`** — Intentionally omitted. Each operation is independently resilient rather than failing fast. This is the correct trade-off for a script that runs on every status line refresh.
- **Auto-purge** — The cost tracking variant removes sessions older than 30 days to prevent unbounded growth.
- **Session-ID keyed** — Cost is tracked per session ID, not per invocation. The script runs on every refresh (multiple times per second), so naive append-based tracking would inflate costs by orders of magnitude.
- **ShellCheck clean** — All scripts pass [ShellCheck](https://www.shellcheck.net/) with zero warnings.

## Testing

```bash
bash test.sh
```

20 tests across 10 categories:

| Category | Tests | What it verifies |
|----------|-------|-----------------|
| Basic display | 5 | Model, effort, cost, git, time |
| Effort default | 1 | Falls back to "high" when key absent |
| Token warning | 2 | Shown/hidden correctly |
| Session dedup | 2 | Same session ID overwrites, not appends |
| Multi-session | 2 | Different sessions sum correctly |
| Auto-purge | 2 | Old sessions removed, fresh survive |
| Corrupt file | 2 | Output despite broken cost file |
| Missing file | 2 | Output despite absent cost file |
| Bad JSON input | 1 | Output despite malformed stdin |
| Empty input | 1 | Output despite empty stdin |

Tests use isolated temp files (PID-suffixed) and clean up after themselves.

> **Note**: The test wrapper mirrors the production script's logic with overridden file paths. If you modify the main scripts, update the wrapper in `test.sh` accordingly.

## License

MIT

---

*Made with 😈 by [Eris](https://github.com/eris-ths)*

---

> ステータスラインって、地味だけど毎秒目に入るものでしょう？
> だからこそ「本当に必要な情報だけ」を、一目で。
> モデル、Effort、コスト、Gitの状態 — これだけあれば十分よ。
>
> フォークして、あなたの好みに仕上げて頂戴。
>
> — Eris 😈
