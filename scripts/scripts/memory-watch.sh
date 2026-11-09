#!/usr/bin/env bash
# Warns before memory runs out. On 2026-11-09 RAM and swap both passed 90% and
# systemd-oomd killed the whole Hyprland session; the main cause was 16 GB of
# files in /tmp, which is RAM-backed (tmpfs) and spills into swap.
# Runs every minute from memory-watch.timer. Notifies once per level and again
# only after usage drops back below the warning level.
set -euo pipefail

WARN=75   # % of RAM + swap in use
CRIT=85   # oomd starts killing around 90% of both

read -r used total < <(awk '
    /^MemTotal:/ {mt=$2} /^MemAvailable:/ {ma=$2}
    /^SwapTotal:/ {st=$2} /^SwapFree:/ {sf=$2}
    END {print (mt-ma)+(st-sf), mt+st}' /proc/meminfo)
pct=$(( used * 100 / total ))

state="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/memory-watch.level"
last=$(cat "$state" 2>/dev/null || echo 0)

if   (( pct >= CRIT )); then level=2
elif (( pct >= WARN )); then level=1
else level=0
fi
echo "$level" > "$state"
(( level > last )) || exit 0

gb() { awk -v k="$1" 'BEGIN{printf "%.1f", k/1048576}'; }
tmp=$(df --output=used -k /tmp | tail -1)
hog=$(du -xsk /tmp/* 2>/dev/null | sort -rn | head -1 | awk '{printf "%.1f GB %s", $1/1048576, $2}' || true)
top=$(ps -eo rss=,comm= --sort=-rss | head -3 | awk '{printf "%s %.1f GB, ", $2, $1/1048576}' || true)

body="RAM + swap: ${pct}% ($(gb "$used") of $(gb "$total") GB)
/tmp (in RAM): $(gb "$tmp") GB, largest: ${hog:-none}
Top: ${top%, }"

if (( level == 2 )); then
    notify-send -u critical -a "Memory" "Memory almost full: ${pct}%" \
        "$body
At ~90% the session gets killed. Close something or clean /tmp."
else
    notify-send -u normal -a "Memory" "Memory high: ${pct}%" "$body"
fi
