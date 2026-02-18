#!/bin/bash
#
# Claude Code Enhanced Status Line
# https://github.com/eris-ths/claude-code-statusline
#
# Output: ⏰14:30 my-project | 🌿main 📝5 | 💰$1.05 | 🤖Opus 4.6 [high]
#
# Setup:
#   1. cp status_line_generator.sh ~/.claude/scripts/
#   2. chmod +x ~/.claude/scripts/status_line_generator.sh
#   3. Add to ~/.claude/settings.json:
#      { "statusLine": { "script": "~/.claude/scripts/status_line_generator.sh" } }
#
# Design principle: status line scripts must NEVER fail.
# Partial output beats no output. All operations are guarded.

# ─── Input ───
input=$(cat)
json_val() { echo "$input" | jq -r "$1" 2>/dev/null || echo "${2:-}"; }

# ─── Model & Effort ───
model_name=$(json_val '.model.display_name // ""')
# effortLevel is absent from status line JSON; read from settings.json
# When set to "high" (default), the key is removed — fall back to "high"
effort=$(jq -r '.effortLevel // "high"' "$HOME/.claude/settings.json" 2>/dev/null || echo "high")

# ─── Cost ───
cost_usd=$(json_val '.cost.total_cost_usd // empty')
if [ -n "$cost_usd" ]; then
    cost_str=$(printf '$%.2f' "$cost_usd" 2>/dev/null) || cost_str="N/A"
else
    cost_str="N/A"
fi

# ─── Token overflow ───
token_warn=""
if [ "$(json_val '.exceeds_200k_tokens // false' "false")" = "true" ]; then
    token_warn=" 🔴200k+"
fi

# ─── Git ───
git_str=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null) || branch="detached"
    changed=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    git_str="🌿${branch}"
    [ "${changed:-0}" -gt 0 ] && git_str="${git_str} 📝${changed}"
fi

# ─── Model display ───
model_str=""
if [ -n "$model_name" ]; then
    model_str=" | 🤖${model_name} [${effort}]"
fi

# ─── Output ───
printf '⏰%s %s | %s | 💰%s%s%s' \
    "$(date +%H:%M)" \
    "$(basename "$(pwd)")" \
    "$git_str" \
    "$cost_str" \
    "$token_warn" \
    "$model_str"
