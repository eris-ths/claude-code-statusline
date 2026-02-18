#!/bin/bash
# ═══════════════════════════════════════════════════════
# StatusLine Generator テスト
# テスト用隔離ファイルを使い、本番環境に影響しない
# ═══════════════════════════════════════════════════════

PASS=0
FAIL=0

# ─── テスト用隔離環境 ───
export TEST_COST_FILE="/tmp/test_cost_tracking_$$.json"
export TEST_SETTINGS_FILE="/tmp/test_settings_$$.json"
WRAPPER="/tmp/test_statusline_wrapper_$$.sh"

echo '{"effortLevel":"medium"}' > "$TEST_SETTINGS_FILE"

# テスト用ラッパー（本番スクリプトと同じロジック、ファイルパスだけ差替）
cat > "$WRAPPER" << 'WEOF'
#!/bin/bash
COST_FILE="$TEST_COST_FILE"
RATE=146.87
PURGE_DAYS="${TEST_PURGE_DAYS:-30}"

input=$(cat)
json_val() { echo "$input" | jq -r "$1" 2>/dev/null || echo "${2:-}"; }

model_name=$(json_val '.model.display_name // ""')
effort=$(jq -r '.effortLevel // "high"' "$TEST_SETTINGS_FILE" 2>/dev/null || echo "high")

cost_usd=$(json_val '.cost.total_cost_usd // empty')
session_id=$(json_val '.session_id // ""')
cost_str="N/A"

if [ -n "$cost_usd" ]; then
    cost_yen=$(echo "$cost_usd * $RATE" | bc -l 2>/dev/null | xargs printf "%.0f" 2>/dev/null) || cost_yen=0
    cost_str="¥${cost_yen}"

    if [ -n "$session_id" ] && [ -f "$COST_FILE" ]; then
        {
            cutoff=$(date -v-${PURGE_DAYS}d +%Y-%m-%d 2>/dev/null || date -d "${PURGE_DAYS} days ago" +%Y-%m-%d 2>/dev/null || echo "")
            jq --arg sid "$session_id" \
               --arg date "$(date +%Y-%m-%d)" \
               --arg week "$(date +%Y-W%U)" \
               --argjson cost "${cost_yen:-0}" \
               --arg ts "$(date +"%Y-%m-%d %H:%M:%S")" \
               --arg cutoff "$cutoff" \
               '
               .sessions[$sid] = {timestamp: $ts, cost_yen: $cost, date: $date, week: $week} |
               if $cutoff != "" then
                   .sessions |= with_entries(select(.value.date >= $cutoff))
               else . end |
               .daily_totals = (reduce (.sessions | to_entries[].value) as $s ({};
                   .[$s.date] = ((.[$s.date] // 0) + $s.cost_yen))) |
               .weekly_totals = (reduce (.sessions | to_entries[].value) as $s ({};
                   .[$s.week] = ((.[$s.week] // 0) + $s.cost_yen)))
               ' "$COST_FILE" > "${COST_FILE}.tmp" && mv "${COST_FILE}.tmp" "$COST_FILE"
        } 2>/dev/null || true
    fi
fi

cumulative=""
if [ -f "$COST_FILE" ]; then
    daily=$(jq -r --arg d "$(date +%Y-%m-%d)" '.daily_totals[$d] // 0 | floor' "$COST_FILE" 2>/dev/null) || daily=0
    weekly=$(jq -r --arg w "$(date +%Y-W%U)" '.weekly_totals[$w] // 0 | floor' "$COST_FILE" 2>/dev/null) || weekly=0
    cumulative=" (日¥${daily}/週¥${weekly})"
fi

token_warn=""
if [ "$(json_val '.exceeds_200k_tokens // false' "false")" = "true" ]; then
    token_warn=" 🔴200k+"
fi

git_str=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null) || branch="detached"
    changed=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    git_str="🌿${branch}"
    [ "${changed:-0}" -gt 0 ] && git_str="${git_str} 📝${changed}"
fi

model_str=""
if [ -n "$model_name" ]; then
    model_str=" | 🤖${model_name} [${effort}]"
fi

printf '⏰%s %s | %s | 💰%s%s%s%s' \
    "$(date +%H:%M)" "$(basename "$(pwd)")" "$git_str" \
    "$cost_str" "$cumulative" "$token_warn" "$model_str"
WEOF
chmod +x "$WRAPPER"

SCRIPT="$WRAPPER"
COST_FILE="$TEST_COST_FILE"

reset_cost_file() {
    echo '{"sessions": {}, "daily_totals": {}, "weekly_totals": {}}' > "$COST_FILE"
}

# ─── Assertions ───
assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected: $expected"
        echo "     actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" pattern="$2" actual="$3"
    if echo "$actual" | grep -q "$pattern"; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     pattern: $pattern"
        echo "     actual:  $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" pattern="$2" actual="$3"
    if echo "$actual" | grep -q "$pattern"; then
        echo "  ❌ $desc"
        echo "     should NOT contain: $pattern"
        echo "     actual:  $actual"
        FAIL=$((FAIL + 1))
    else
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    fi
}

make_json() {
    local model="${1:-Test}" cost="${2:-0}" sid="${3:-test}" exceed="${4:-false}"
    echo "{\"model\":{\"id\":\"test\",\"display_name\":\"$model\"},\"cost\":{\"total_cost_usd\":$cost},\"session_id\":\"$sid\",\"exceeds_200k_tokens\":$exceed}"
}

date_key=$(date +"%Y-%m-%d")

# ═══════════════════════════════════════════════════════
echo "=== 1. Display: basic output ==="
reset_cost_file
output=$(make_json "Opus 4.6" 1.05 "test-1" | bash "$SCRIPT")
assert_contains "Model name" "Opus 4.6" "$output"
assert_contains "Effort level" "\[medium\]" "$output"
assert_contains "Cost in yen" "¥" "$output"
assert_contains "Git branch" "🌿" "$output"
assert_contains "Time format" "⏰" "$output"

# ═══════════════════════════════════════════════════════
echo "=== 2. Display: effort default (high) ==="
echo '{}' > "$TEST_SETTINGS_FILE"
output=$(make_json "Sonnet 4.6" 0.5 "test-2" | bash "$SCRIPT")
assert_contains "Effort defaults to high" "\[high\]" "$output"
echo '{"effortLevel":"medium"}' > "$TEST_SETTINGS_FILE"  # restore

# ═══════════════════════════════════════════════════════
echo "=== 3. Display: 200k token warning ==="
output=$(make_json "Test" 0 "test-3a" true | bash "$SCRIPT")
assert_contains "200k warning shown" "🔴200k+" "$output"

output=$(make_json "Test" 0 "test-3b" false | bash "$SCRIPT")
assert_not_contains "200k warning hidden" "🔴200k+" "$output"

# ═══════════════════════════════════════════════════════
echo "=== 4. Cost tracking: session dedup ==="
reset_cost_file
make_json "Test" 1.0 "sess-A" | bash "$SCRIPT" > /dev/null
make_json "Test" 2.0 "sess-A" | bash "$SCRIPT" > /dev/null
make_json "Test" 3.0 "sess-A" | bash "$SCRIPT" > /dev/null

session_count=$(jq '.sessions | length' "$COST_FILE")
assert_eq "Session count is 1 (not 3)" "1" "$session_count"

daily=$(jq -r --arg d "$date_key" '.daily_totals[$d] // 0' "$COST_FILE")
assert_eq "Daily total = latest only (441)" "441" "$daily"

# ═══════════════════════════════════════════════════════
echo "=== 5. Cost tracking: multiple sessions ==="
reset_cost_file
make_json "Test" 1.0 "sess-X" | bash "$SCRIPT" > /dev/null
make_json "Test" 2.0 "sess-Y" | bash "$SCRIPT" > /dev/null

session_count=$(jq '.sessions | length' "$COST_FILE")
assert_eq "Two sessions recorded" "2" "$session_count"

daily=$(jq -r --arg d "$date_key" '.daily_totals[$d] // 0' "$COST_FILE")
assert_eq "Daily total = sum (441)" "441" "$daily"

# ═══════════════════════════════════════════════════════
echo "=== 6. Cost tracking: auto-purge old sessions ==="
reset_cost_file
# Inject an old session (60 days ago) directly into the cost file
old_date=$(date -v-60d +%Y-%m-%d 2>/dev/null || date -d "60 days ago" +%Y-%m-%d)
old_week=$(date -v-60d +%Y-W%U 2>/dev/null || date -d "60 days ago" +%Y-W%U)
jq --arg d "$old_date" --arg w "$old_week" \
   '.sessions["old-session"] = {timestamp: "2025-12-01 10:00:00", cost_yen: 999, date: $d, week: $w}' \
   "$COST_FILE" > "${COST_FILE}.tmp" && mv "${COST_FILE}.tmp" "$COST_FILE"

# Now run with a fresh session — old one should be purged
export TEST_PURGE_DAYS=30
make_json "Test" 1.0 "fresh-session" | bash "$SCRIPT" > /dev/null
unset TEST_PURGE_DAYS

session_count=$(jq '.sessions | length' "$COST_FILE")
assert_eq "Old session purged, only fresh remains" "1" "$session_count"

has_old=$(jq 'has("old-session")' "$COST_FILE" 2>/dev/null)
assert_eq "Old session key gone" "false" "$has_old"

# ═══════════════════════════════════════════════════════
echo "=== 7. Resilience: corrupted cost file ==="
echo 'NOT JSON!!!' > "$COST_FILE"
output=$(make_json "Opus 4.6" 1.05 "test-corrupt" | bash "$SCRIPT")
# Script must still produce output (cost tracking fails silently)
assert_contains "Output despite corrupt file" "Opus 4.6" "$output"
assert_contains "Cost still shown" "¥" "$output"

# ═══════════════════════════════════════════════════════
echo "=== 8. Resilience: missing cost file ==="
rm -f "$COST_FILE"
output=$(make_json "Opus 4.6" 0.5 "test-missing" | bash "$SCRIPT")
assert_contains "Output despite missing file" "Opus 4.6" "$output"
assert_not_contains "No cumulative when file missing" "日¥" "$output"

# ═══════════════════════════════════════════════════════
echo "=== 9. Resilience: malformed input JSON ==="
output=$(echo 'not json at all' | bash "$SCRIPT")
# Should still output something (time, git, etc.)
assert_contains "Output despite bad JSON" "⏰" "$output"

# ═══════════════════════════════════════════════════════
echo "=== 10. Resilience: empty input ==="
output=$(echo '' | bash "$SCRIPT")
assert_contains "Output despite empty input" "⏰" "$output"

# ═══════════════════════════════════════════════════════
# Cleanup
rm -f "$TEST_COST_FILE" "${TEST_COST_FILE}.tmp" "$TEST_SETTINGS_FILE" "$WRAPPER"

echo ""
echo "═══════════════════════════════════════"
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo "═══════════════════════════════════════"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
