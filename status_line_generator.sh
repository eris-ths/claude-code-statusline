#!/bin/bash

# Claude Code Enhanced Status Line Generator
# Shows: Time | Project | Git branch + changes | Cost | Model [Effort]
#
# Setup:
#   1. Copy this script to ~/.claude/scripts/status_line_generator.sh
#   2. chmod +x ~/.claude/scripts/status_line_generator.sh
#   3. Add to ~/.claude/settings.json:
#      "statusLine": {
#        "script": "~/.claude/scripts/status_line_generator.sh"
#      }
#
# Output example:
#   ⏰14:30 my-project | 🌿main 📝5 | 💰$1.05 | 🤖Opus 4.6 [high]

input=$(cat)

# --- Basic info ---
dir="$(basename "$(pwd)")"
current_time=$(date +%H:%M)

# --- Model & Effort ---
model_name=$(echo "$input" | jq -r '.model.display_name // ""' 2>/dev/null || echo "")
# effortLevel is not included in the status line JSON input,
# so we read it from settings.json (defaults to "high" when key is absent)
effort_level=$(jq -r '.effortLevel // "high"' "$HOME/.claude/settings.json" 2>/dev/null || echo "high")

# --- Session cost ---
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // "N/A"' 2>/dev/null || echo "N/A")
if [ "$cost_usd" = "N/A" ]; then
    session_cost="N/A"
else
    session_cost=$(printf '$%.2f' "$cost_usd" 2>/dev/null || echo "N/A")
fi

# --- Token overflow indicator ---
exceeds_200k=$(echo "$input" | jq -r '.exceeds_200k_tokens // false' 2>/dev/null || echo "false")
token_indicator=""
if [ "$exceeds_200k" = "true" ]; then
    token_indicator=" 🔴200k+"
fi

# --- Git info ---
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch="🌿$(git branch --show-current 2>/dev/null || echo 'detached')"
    changed_files=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$changed_files" -gt 0 ]; then
        git_status=" 📝${changed_files}"
    else
        git_status=""
    fi
else
    branch=""
    git_status=""
fi

# --- Model & Effort display ---
model_effort_str=""
if [ -n "$model_name" ]; then
    model_effort_str=" | 🤖${model_name}"
    if [ -n "$effort_level" ]; then
        model_effort_str="${model_effort_str} [${effort_level}]"
    fi
fi

# --- Output ---
printf '⏰%s %s | %s%s | 💰%s%s%s' \
    "$current_time" \
    "$dir" \
    "$branch" \
    "$git_status" \
    "$session_cost" \
    "$token_indicator" \
    "$model_effort_str"
