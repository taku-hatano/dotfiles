#!/usr/bin/env bash
# Claude Code statusline script
# Line 1: Model | Context% | +added/-removed | branch
# Line 2: 5h rate limit progress bar + reset time (Asia/Tokyo)
# Line 3: 7d rate limit progress bar + reset date/time (Asia/Tokyo)

set -euo pipefail

CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_TTL=360
CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
USAGE_API="https://api.anthropic.com/api/oauth/usage"

# --- 24-bit color helpers ---
RESET="\033[0m"

# Palette
C_GREEN="\033[38;2;151;201;195m"   # #97C9C3
C_YELLOW="\033[38;2;229;192;123m"  # #E5C07B
C_RED="\033[38;2;224;108;117m"     # #E06C75
C_GRAY="\033[38;2;74;88;92m"       # #4A585C (separator / muted text)

# Pick color by percentage (integer)
pct_color() {
  local pct="$1"
  if [ "$pct" -ge 80 ] 2>/dev/null; then
    printf '%s' "$C_RED"
  elif [ "$pct" -ge 50 ] 2>/dev/null; then
    printf '%s' "$C_YELLOW"
  else
    printf '%s' "$C_GREEN"
  fi
}

# Gradient color for context window usage (0% green → 40% yellow → 80%+ red)
# Linear RGB interpolation with 80% as the critical threshold
ctx_color() {
  local pct="$1"
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  local r g b
  if [ "$pct" -le 40 ]; then
    # Green(151,201,195) → Yellow(229,192,123)
    local t=$((pct * 100 / 40))
    r=$(( 151 + (229 - 151) * t / 100 ))
    g=$(( 201 + (192 - 201) * t / 100 ))
    b=$(( 195 + (123 - 195) * t / 100 ))
  elif [ "$pct" -le 80 ]; then
    # Yellow(229,192,123) → Red(224,108,117)
    local t=$(( (pct - 40) * 100 / 40 ))
    r=$(( 229 + (224 - 229) * t / 100 ))
    g=$(( 192 + (108 - 192) * t / 100 ))
    b=$(( 123 + (117 - 123) * t / 100 ))
  else
    # 80%+: solid red
    r=224; g=108; b=117
  fi
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

# Build a 10-segment progress bar using block characters
progress_bar() {
  local pct="$1"
  local filled=$(( pct * 10 / 100 ))
  [ "$filled" -gt 10 ] && filled=10
  local empty=$(( 10 - filled ))
  local bar=""
  local i
  for (( i=0; i<filled; i++ )); do bar="${bar}▰"; done
  for (( i=0; i<empty; i++ )); do bar="${bar}▱"; done
  printf '%s' "$bar"
}

# --- Read stdin JSON ---
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

# --- Git branch ---
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null || true)
fi

# --- Git diff stat (added/removed lines vs HEAD) ---
diff_stat=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  stat_out=$(git --no-optional-locks -C "$cwd" diff --shortstat HEAD 2>/dev/null || true)
  if [ -n "$stat_out" ]; then
    added=$(echo "$stat_out" | grep -oP '\d+(?= insertion)' || true)
    removed=$(echo "$stat_out" | grep -oP '\d+(?= deletion)' || true)
    added="${added:-0}"
    removed="${removed:-0}"
    diff_stat="+${added}/-${removed}"
  fi
fi

# --- Uncommitted file count (staged + unstaged + untracked) ---
uncommitted=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  changed=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null | wc -l)
  changed=$(( changed + 0 ))  # trim whitespace
  if [ "$changed" -gt 0 ]; then
    uncommitted="$changed"
  fi
fi

# --- Ahead / Behind upstream ---
ahead=""
behind=""
if [ -n "$branch" ]; then
  ab=$(git --no-optional-locks -C "$cwd" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || true)
  if [ -n "$ab" ]; then
    ahead=$(echo "$ab" | awk '{print $1}')
    behind=$(echo "$ab" | awk '{print $2}')
  fi
fi

# --- Project (git root) & relative path ---
project_name=""
rel_path=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  project_name=$(basename "$git_root")
  # Relative path from git root to cwd
  if [ "$cwd" != "$git_root" ]; then
    rel_path="${cwd#"$git_root"/}"
  fi
else
  project_name=$(basename "$cwd")
fi

# --- Line 1 assembly ---
SEP="${C_GRAY} │ ${RESET}"

# Model
line1="${C_GREEN}🤖 ${model}${RESET}"

# Context %
if [ -n "$used_pct" ]; then
  pct_int=${used_pct%.*}
  col=$(ctx_color "$pct_int")
  line1="${line1}${SEP}${col}📊 ${pct_int}%${RESET}"
fi

# Diff stat
if [ -n "$diff_stat" ]; then
  line1="${line1}${SEP}${C_YELLOW}✏️ ${diff_stat}${RESET}"
fi

# Branch + ahead/behind
if [ -n "$branch" ]; then
  branch_part="🔀 ${branch}"
  ab_part=""
  if [ -n "$ahead" ] && [ "$ahead" -gt 0 ] 2>/dev/null; then
    ab_part="${ab_part}↑${ahead}"
  fi
  if [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null; then
    ab_part="${ab_part}↓${behind}"
  fi
  if [ -n "$ab_part" ]; then
    branch_part="${branch_part} ${C_YELLOW}${ab_part}${RESET}"
  fi
  line1="${line1}${SEP}${C_GREEN}${branch_part}${RESET}"
fi

# Uncommitted files
if [ -n "$uncommitted" ]; then
  line1="${line1}${SEP}${C_YELLOW}● ${uncommitted} changed${RESET}"
fi

# Project name
line1="${line1}${SEP}${C_GREEN}📁 ${project_name}${RESET}"

# Relative path (if inside subdirectory)
if [ -n "$rel_path" ]; then
  line1="${line1}${SEP}${C_GRAY}📂 ${rel_path}${RESET}"
fi

# --- Rate limit cache / fetch ---
fetch_usage() {
  # Rate limit display disabled – early return to skip API request
  return 1
  if [ ! -f "$CREDENTIALS_FILE" ]; then
    return 1
  fi
  token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE" 2>/dev/null)
  if [ -z "$token" ]; then
    return 1
  fi
  curl -sf -H "Authorization: Bearer $token" "$USAGE_API" 2>/dev/null
}

usage_json=""
if [ -f "$CACHE_FILE" ]; then
  cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  age=$(( now - cache_mtime ))
  if [ "$age" -lt "$CACHE_TTL" ]; then
    usage_json=$(cat "$CACHE_FILE")
  fi
fi

if [ -z "$usage_json" ]; then
  fetched=$(fetch_usage || true)
  if [ -n "$fetched" ]; then
    usage_json="$fetched"
    echo "$usage_json" > "$CACHE_FILE"
  fi
fi

# Format ISO timestamp for 5h row: "4pm (Asia/Tokyo)"
fmt_reset_5h() {
  local iso="$1"
  [ -z "$iso" ] && echo "" && return
  TZ="Asia/Tokyo" date -d "$iso" "+%-I%p (%Z)" 2>/dev/null | sed 's/AM/am/;s/PM/pm/' || echo ""
}

# Format ISO timestamp for 7d row: "Mar 6 at 1pm (Asia/Tokyo)"
fmt_reset_7d() {
  local iso="$1"
  [ -z "$iso" ] && echo "" && return
  TZ="Asia/Tokyo" date -d "$iso" "+%b %-d at %-I%p (%Z)" 2>/dev/null | sed 's/AM/am/;s/PM/pm/' || echo ""
}

# --- Lines 2 & 3: rate limit rows ---
line2=""
line3=""

if [ -z "$usage_json" ]; then
  line2="  ${C_GRAY}5h  ▱▱▱▱▱▱▱▱▱▱  -- (unavailable)${RESET}"
  line3="  ${C_GRAY}7d  ▱▱▱▱▱▱▱▱▱▱  -- (unavailable)${RESET}"
elif [ -n "$usage_json" ]; then
  # 5h
  limit_5h_used=$(echo "$usage_json" | jq -r '
    .rate_limits[]?
    | select(.window | test("5h"; "i"))
    | .used // empty' 2>/dev/null | head -1)
  limit_5h_max=$(echo "$usage_json" | jq -r '
    .rate_limits[]?
    | select(.window | test("5h"; "i"))
    | .limit // empty' 2>/dev/null | head -1)
  limit_5h_reset=$(echo "$usage_json" | jq -r '
    .rate_limits[]?
    | select(.window | test("5h"; "i"))
    | .reset_at // .resetsAt // empty' 2>/dev/null | head -1)

  # 7d
  limit_7d_used=$(echo "$usage_json" | jq -r '
    .rate_limits[]?
    | select(.window | test("7d"; "i"))
    | .used // empty' 2>/dev/null | head -1)
  limit_7d_max=$(echo "$usage_json" | jq -r '
    .rate_limits[]?
    | select(.window | test("7d"; "i"))
    | .limit // empty' 2>/dev/null | head -1)
  limit_7d_reset=$(echo "$usage_json" | jq -r '
    .rate_limits[]?
    | select(.window | test("7d"; "i"))
    | .reset_at // .resetsAt // empty' 2>/dev/null | head -1)

  # Build line 2 (5h)
  if [ -n "$limit_5h_used" ] && [ -n "$limit_5h_max" ] && [ "$limit_5h_max" -gt 0 ] 2>/dev/null; then
    pct5=$(( limit_5h_used * 100 / limit_5h_max ))
    col5=$(pct_color "$pct5")
    bar5=$(progress_bar "$pct5")
    reset5=$(fmt_reset_5h "$limit_5h_reset")
    reset5_part=""
    [ -n "$reset5" ] && reset5_part="  Resets ${reset5}"
    line2="  ${C_GRAY}5h${RESET}  ${col5}${bar5}${RESET}  ${col5}${pct5}%${RESET}${C_GRAY}${reset5_part}${RESET}"
  fi

  # Build line 3 (7d)
  if [ -n "$limit_7d_used" ] && [ -n "$limit_7d_max" ] && [ "$limit_7d_max" -gt 0 ] 2>/dev/null; then
    pct7=$(( limit_7d_used * 100 / limit_7d_max ))
    col7=$(pct_color "$pct7")
    bar7=$(progress_bar "$pct7")
    reset7=$(fmt_reset_7d "$limit_7d_reset")
    reset7_part=""
    [ -n "$reset7" ] && reset7_part="  Resets ${reset7}"
    line3="  ${C_GRAY}7d${RESET}  ${col7}${bar7}${RESET}  ${col7}${pct7}%${RESET}${C_GRAY}${reset7_part}${RESET}"
  fi
fi

# --- Output ---
printf '%b\n' "$line1"
[ -n "$line2" ] && printf '%b\n' "$line2"
[ -n "$line3" ] && printf '%b\n' "$line3"
