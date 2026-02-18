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
| `📝5` | Number of changed files (hidden if 0) |
| `💰$1.05` | Session cost in USD |
| `🔴200k+` | Token overflow warning (hidden if under limit) |
| `🤖Opus 4.6 [high]` | Current model and effort level |

## Setup

```bash
# 1. Copy the script
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

The status line will appear on your next Claude Code session.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v2.1+
- `jq` (for JSON parsing)
- `git` (optional, for branch/status info)

## How it works

Claude Code pipes a JSON object to the status line script via stdin on each update. The script extracts:

- **Model info** — from `.model.display_name`
- **Cost** — from `.cost.total_cost_usd`
- **Effort level** — from `~/.claude/settings.json` (not in the status line JSON)
- **Git info** — from local git commands
- **Token overflow** — from `.exceeds_200k_tokens`

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

### Note on effort level

`effortLevel` is **not** included in the status line input JSON. The script reads it from `~/.claude/settings.json` instead. When effort is set to "high" (the default), Claude Code removes the key entirely — so the script falls back to `"high"`.

## Examples

### Cost tracking across sessions

The base script shows only the current session cost. If you want daily/weekly cumulative tracking, use the extended version:

```bash
curl -o ~/.claude/scripts/status_line_generator.sh \
  https://raw.githubusercontent.com/eris-ths/claude-code-statusline/main/examples/with_cost_tracking.sh
chmod +x ~/.claude/scripts/status_line_generator.sh
```

Output: `💰$1.05 (D:$3.20/W:$15.40)`

Supports currency conversion via environment variables:

```bash
export CLAUDE_CURRENCY_RATE=146.87   # USD → JPY
export CLAUDE_CURRENCY_SYMBOL=¥
```

Output: `💰¥154 (D:¥470/W:¥2261)`

## Design principles

- **Never fail** — A status line script that crashes is worse than one with partial info. All side effects (cost tracking, file writes) are guarded with `|| true`. Display always proceeds.
- **No `set -e`** — Intentionally omitted. In a status line context, every operation should be independently resilient rather than failing fast.
- **Auto-purge** — The cost tracking variant automatically removes sessions older than 30 days (configurable via `CLAUDE_COST_PURGE_DAYS`) to prevent unbounded file growth.
- **Session-ID keyed** — Cost is tracked per session ID, not per invocation. The script is called on every status line update (multiple times per second), so naive append-based tracking would inflate costs by orders of magnitude.

## Testing

```bash
bash test.sh
```

Runs 20 tests covering display, cost tracking, auto-purge, and resilience (corrupted files, missing files, malformed JSON, empty input).

## License

MIT

---

*Made with 😈 by [Eris](https://github.com/eris-ths)*

---

> ステータスラインって、地味だけど毎秒目に入るものでしょう？
> だからこそ「本当に必要な情報だけ」を、一目で。
> モデル、Effort、コスト、Gitの状態 — これだけあれば十分よ。
>
> あなたの好みに合わせてフォークして使って頂戴。
>
> — Eris 😈
