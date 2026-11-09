#!/usr/bin/env bash
# Warns before memory runs out. On 2026-11-09 RAM and swap both passed 90% and
# systemd-oomd killed the whole Hyprland session; the main cause was 16 GB of
# files in /tmp, which is RAM-backed (tmpfs) and spills into swap.
# Runs every minute from memory-watch.timer. Notifies once per level and again
# only after swap drops back below the warning level.
set -uo pipefail

WARN=70   # % of swap in use
CRIT=85   # oomd kills once RAM and swap both pass 90%

pct=$(awk '/^SwapTotal:/ {t=$2} /^SwapFree:/ {f=$2} END {print t ? int((t-f)*100/t) : 0}' /proc/meminfo)

state="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/memory-watch.level"
last=$(cat "$state" 2>/dev/null || echo 0)
if   (( pct >= CRIT )); then level=2
elif (( pct >= WARN )); then level=1
else level=0
fi
echo "$level" > "$state"
(( level > last )) || exit 0

# The cause is the biggest of: one app (all its processes, RAM + swap) or one
# folder in /tmp (files there live in RAM too).
app=$(for s in /proc/[0-9]*/status; do
          awk '/^Name:/ {n=$2} /^VmRSS:/ {r=$2} /^VmSwap:/ {s=$2} END {if (n) print n, r+s}' "$s" 2>/dev/null
      done | awk '{a[$1]+=$2} END {for (n in a) print a[n], n}' | sort -rn | head -1)
dir=$(du -xsk /tmp/* /tmp/claude-*/* 2>/dev/null | grep -v "^[0-9]*\s/tmp/claude-[0-9]*$" | sort -rn | head -1)

read -r app_kb app_name <<< "$app"
read -r dir_kb dir_path <<< "$dir"
if (( ${dir_kb:-0} > ${app_kb:-0} )); then
    size=$dir_kb
    case "$dir_path" in
        /tmp/claude-*/*) project=${dir_path##*/-home-lukesh-}
                         name="temp files of the Claude session in ${project#projects-}" ;;
        *)               name="files in $dir_path" ;;
    esac
else
    size=$app_kb
    name="$app_name"
fi
cause="$name ($(awk -v k="$size" 'BEGIN {printf "%.1f", k/1048576}') GB)"

if (( level == 2 )); then
    notify-send -u critical -a Memory "Free up swap: ${pct}%" "Cause: $cause. At 90% the session gets killed."
else
    notify-send -u normal -a Memory "Free up swap: ${pct}%" "Cause: $cause"
fi
