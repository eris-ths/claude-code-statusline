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

### 1. Copy the script

```bash
mkdir -p ~/.claude/scripts
cp status_line_generator.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/status_line_generator.sh
```

### 2. Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "script": "~/.claude/scripts/status_line_generator.sh"
  }
}
```

That's it. The status line will appear on your next Claude Code session.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v2.1+
- `jq` (for JSON parsing)
- `git` (for branch/status info)

## How it works

Claude Code pipes a JSON object to the status line script via stdin on each update. The script extracts:

- **Model info** from the input JSON (`.model.display_name`)
- **Cost** from the input JSON (`.cost.total_cost_usd`)
- **Effort level** from `~/.claude/settings.json` (not available in the status line JSON input)
- **Git info** from local git commands

### Available JSON fields

The status line input JSON contains these fields:

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

## Customization

Fork this script and customize it to your needs. Some ideas:

- **Currency conversion**: Replace `$` formatting with your local currency
- **Cost tracking**: Accumulate costs across sessions to a file
- **Context usage**: Show `context_window.used_percentage` as a progress bar
- **Timestamp**: Show elapsed time instead of clock time

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
