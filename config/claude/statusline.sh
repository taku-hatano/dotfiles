#!/usr/bin/env bash
# Claude Code statusline script
# Line 1: Model | +added/-removed | branch | uncommitted | project
# Line 2: Session ctx | 5h limit | 7d limit (all SPARK bars)

set -euo pipefail

# --- 24-bit color helpers ---
RESET="\033[0m"

# Palette - general
C_GREEN="\033[38;2;151;201;195m"   # #97C9C3
C_YELLOW="\033[38;2;229;192;123m"  # #E5C07B
C_RED="\033[38;2;224;108;117m"     # #E06C75
C_GRAY="\033[38;2;74;88;92m"       # #4A585C (separator / muted text)

# Palette - limit bars (fixed color per category)
C_CTX="\033[38;2;86;182;194m"      # #56B6C2  cyan/teal - session context
C_5H="\033[38;2;209;154;102m"      # #D19A66  amber/orange - 5h limit
C_7D="\033[38;2;198;120;221m"      # #C678DD  purple/lavender - 7d limit

# Build a 10-segment progress bar using spark characters for smooth granularity
# Each segment represents 10%, with partial fill shown via spark height
SPARKS=' ▁▂▃▄▅▆▇█'
progress_bar() {
  local pct="$1"
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  local bar=""
  local i
  for (( i=0; i<10; i++ )); do
    local seg_start=$(( i * 10 ))
    local seg_end=$(( seg_start + 10 ))
    if [ "$pct" -ge "$seg_end" ]; then
      # Fully filled segment
      bar="${bar}█"
    elif [ "$pct" -le "$seg_start" ]; then
      # Empty segment
      bar="${bar} "
    else
      # Partial segment: map remainder (1-9) to spark index (1-8)
      local remainder=$(( pct - seg_start ))
      local idx=$(( (remainder * 8 + 5) / 10 ))
      [ "$idx" -lt 1 ] && idx=1
      [ "$idx" -gt 8 ] && idx=8
      local spark="${SPARKS:$idx:1}"
      bar="${bar}${spark}"
    fi
  done
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

# Project name + relative path
dir_display="${project_name}"
[ -n "$rel_path" ] && dir_display="${project_name}/${rel_path}"
line1="${C_GREEN}📁 ${dir_display}${RESET}"

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

# Diff stat
if [ -n "$diff_stat" ]; then
  line1="${line1}${SEP}${C_YELLOW}✏️ ${diff_stat}${RESET}"
fi

# Uncommitted files
if [ -n "$uncommitted" ]; then
  line1="${line1}${SEP}${C_YELLOW}● ${uncommitted} changed${RESET}"
fi

# Model
line1="${line1}${SEP}${C_GREEN}🤖 ${model}${RESET}"

# --- Line 2: Session ctx | 5h limit | 7d limit (all SPARK bars) ---

# Format remaining time until reset as compact string (e.g. "2h13m", "3d5h")
fmt_remaining() {
  local ts="$1"
  [ -z "$ts" ] || [ "$ts" = "null" ] && return
  local now
  now=$(date +%s)
  local diff=$(( ts - now ))
  [ "$diff" -le 0 ] && printf 'now' && return
  local d=$(( diff / 86400 ))
  local h=$(( (diff % 86400) / 3600 ))
  local m=$(( (diff % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then
    printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then
    printf '%dh%dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

# Session context usage
pct_int=${used_pct%.*}
ctx_bar=$(progress_bar "$pct_int")
session_part="${C_CTX}Ctx ${ctx_bar} ${pct_int}%${RESET}"

# 5h rate limit
pct5_raw=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
reset5_ts=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
if [ -n "$pct5_raw" ]; then
  pct5=${pct5_raw%.*}
  bar5=$(progress_bar "$pct5")
  remain5=$(fmt_remaining "$reset5_ts")
  reset5_part=""
  [ -n "$remain5" ] && reset5_part="${C_GRAY}(${remain5})${RESET}"
  limit5_part="${C_5H}5h ${bar5} ${pct5}%${RESET} ${reset5_part}"
else
  limit5_part="${C_5H}5h ${C_GRAY}░░░░░░░░░░ --${RESET}"
fi

# 7d rate limit
pct7_raw=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
reset7_ts=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)
if [ -n "$pct7_raw" ]; then
  pct7=${pct7_raw%.*}
  bar7=$(progress_bar "$pct7")
  reset7_fmt=""
  if [ -n "$reset7_ts" ] && [ "$reset7_ts" != "null" ]; then
    reset7_fmt=$(TZ="Asia/Tokyo" date -d "@$reset7_ts" "+%-m/%-d %-H:%M" 2>/dev/null || true)
  fi
  reset7_part=""
  [ -n "$reset7_fmt" ] && reset7_part="${C_GRAY}(~${reset7_fmt})${RESET}"
  limit7_part="${C_7D}7d ${bar7} ${pct7}%${RESET} ${reset7_part}"
else
  limit7_part="${C_7D}7d ${C_GRAY}░░░░░░░░░░ --${RESET}"
fi

line2="${session_part}${SEP}${limit5_part}${SEP}${limit7_part}"

# --- Output ---
printf '%b\n' "$line1"
printf '%b\n' "$line2"
