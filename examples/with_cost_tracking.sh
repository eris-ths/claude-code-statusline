#!/bin/bash
#
# Claude Code Status Line — with daily/weekly cost tracking
# https://github.com/eris-ths/claude-code-statusline
#
# Extends the base script with persistent cost history across sessions.
# Tracks per-session costs keyed by session ID (no double-counting).
# Auto-purges sessions older than CLAUDE_COST_PURGE_DAYS (default: 30).
#
# Cost file: ~/.claude/cost_tracking.json (auto-created on first run)
# Format:    { "sessions": {}, "daily_totals": {}, "weekly_totals": {} }
#
# Output: ⏰14:30 my-project | 🌿main 📝5 | 💰$1.05 (D:$3/W:$15) 🔴200k+ | 🤖Opus 4.6 [high]
#
# Design principle: status line scripts must NEVER fail.
# Cost tracking is a side effect — failures are swallowed, display proceeds.

# ─── Config (override via env vars) ───
COST_FILE="${CLAUDE_COST_FILE:-$HOME/.claude/cost_tracking.json}"
CURRENCY_RATE="${CLAUDE_CURRENCY_RATE:-1}"       # e.g. 146.87 for JPY
CURRENCY_SYMBOL="${CLAUDE_CURRENCY_SYMBOL:-$}"   # e.g. ¥ for JPY
PURGE_DAYS="${CLAUDE_COST_PURGE_DAYS:-30}"       # auto-purge threshold

# ─── Input ───
input=$(cat)
json_val() { echo "$input" | jq -r "$1" 2>/dev/null || echo "${2:-}"; }

# ─── Model & Effort ───
model_name=$(json_val '.model.display_name // ""')
effort=$(jq -r '.effortLevel // "high"' "$HOME/.claude/settings.json" 2>/dev/null || echo "high")

# ─── Cost ───
cost_usd=$(json_val '.cost.total_cost_usd // empty')
session_id=$(json_val '.session_id // ""')
cost_str="N/A"

if [ -n "$cost_usd" ]; then
    cost_local=$(echo "$cost_usd * $CURRENCY_RATE" | bc -l 2>/dev/null | xargs printf "%.0f" 2>/dev/null) || cost_local=0
    if [ "$CURRENCY_RATE" = "1" ]; then
        cost_str=$(printf '$%.2f' "$cost_usd" 2>/dev/null) || cost_str="N/A"
    else
        cost_str="${CURRENCY_SYMBOL}${cost_local}"
    fi

    # Side effect: update cost tracking (failures must not kill display)
    if [ -n "$session_id" ]; then
        {
            [ -f "$COST_FILE" ] || echo '{"sessions":{},"daily_totals":{},"weekly_totals":{}}' > "$COST_FILE"
            cutoff=$(date -v-"${PURGE_DAYS}"d +%Y-%m-%d 2>/dev/null || date -d "${PURGE_DAYS} days ago" +%Y-%m-%d 2>/dev/null || echo "")
            jq --arg sid "$session_id" \
               --arg date "$(date +%Y-%m-%d)" \
               --arg week "$(date +%Y-W%U)" \
               --argjson cost "${cost_local:-0}" \
               --arg ts "$(date +"%Y-%m-%d %H:%M:%S")" \
               --arg cutoff "$cutoff" \
               '
               .sessions[$sid] = {timestamp: $ts, cost: $cost, date: $date, week: $week} |
               if $cutoff != "" then
                   .sessions |= with_entries(select(.value.date >= $cutoff))
               else . end |
               .daily_totals = (reduce (.sessions | to_entries[].value) as $s ({};
                   .[$s.date] = ((.[$s.date] // 0) + $s.cost))) |
               .weekly_totals = (reduce (.sessions | to_entries[].value) as $s ({};
                   .[$s.week] = ((.[$s.week] // 0) + $s.cost)))
               ' "$COST_FILE" > "${COST_FILE}.tmp" && mv "${COST_FILE}.tmp" "$COST_FILE"
        } 2>/dev/null || true
    fi
fi

# ─── Cumulative cost ───
cumulative=""
if [ -f "$COST_FILE" ]; then
    daily=$(jq -r --arg d "$(date +%Y-%m-%d)" '.daily_totals[$d] // 0 | floor' "$COST_FILE" 2>/dev/null) || daily=0
    weekly=$(jq -r --arg w "$(date +%Y-W%U)" '.weekly_totals[$w] // 0 | floor' "$COST_FILE" 2>/dev/null) || weekly=0
    if [ "$CURRENCY_RATE" = "1" ]; then
        cumulative=" (D:\$${daily}/W:\$${weekly})"
    else
        cumulative=" (D:${CURRENCY_SYMBOL}${daily}/W:${CURRENCY_SYMBOL}${weekly})"
    fi
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
printf '⏰%s %s | %s | 💰%s%s%s%s' \
    "$(date +%H:%M)" \
    "$(basename "$(pwd)")" \
    "$git_str" \
    "$cost_str" \
    "$cumulative" \
    "$token_warn" \
    "$model_str"
