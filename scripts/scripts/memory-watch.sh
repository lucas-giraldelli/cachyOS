#!/usr/bin/env bash
# Warns before memory runs out. On 2026-11-09 RAM and swap both passed 90% and
# systemd-oomd killed the whole Hyprland session; the main cause was 16 GB of
# files in /tmp, which is RAM-backed (tmpfs) and spills into swap.
# Runs every minute from memory-watch.timer. RAM and swap are watched
# separately; each warns once per level and again only after it drops back
# below the warning level.
set -uo pipefail

RAM_WARN=85;  RAM_CRIT=93    # % of RAM in use (MemTotal - MemAvailable)
SWAP_WARN=70; SWAP_CRIT=85   # % of swap in use; oomd kills once both pass 90%

read -r ram swap < <(awk '
    /^MemTotal:/ {mt=$2} /^MemAvailable:/ {ma=$2}
    /^SwapTotal:/ {st=$2} /^SwapFree:/ {sf=$2}
    END {print int((mt-ma)*100/mt), (st ? int((st-sf)*100/st) : 0)}' /proc/meminfo)

run="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Prints 1 when the level for $1 went up since the last run.
rose() {
    local name=$1 pct=$2 warn=$3 crit=$4 level last
    last=$(cat "$run/memory-watch.$name" 2>/dev/null || echo 0)
    if   (( pct >= crit )); then level=2
    elif (( pct >= warn )); then level=1
    else level=0
    fi
    echo "$level" > "$run/memory-watch.$name"
    (( level > last )) && echo "$level"
}

# The biggest memory user: one app (all its processes, RAM + swap; every Docker
# container counts as "Docker") or one folder in /tmp (files there live in RAM).
cause() {
    local app dir app_kb app_name dir_kb dir_path size name project
    app=$(for p in /proc/[0-9]*; do
              awk -v cg="$(cat "$p/cgroup" 2>/dev/null)" '
                  /^Name:/ {n=$2} /^VmRSS:/ {r=$2} /^VmSwap:/ {s=$2}
                  END {if (cg ~ /docker-/) n="Docker"; if (n) print n, r+s}' "$p/status" 2>/dev/null
          done | awk '{a[$1]+=$2} END {for (n in a) print a[n], n}' | sort -rn | head -1)
    dir=$(du -xsk /tmp/* /tmp/claude-*/* 2>/dev/null | grep -v "^[0-9]*\s/tmp/claude-[0-9]*$" | sort -rn | head -1)
    read -r app_kb app_name <<< "$app"
    read -r dir_kb dir_path <<< "$dir"
    if (( ${dir_kb:-0} > ${app_kb:-0} )); then
        size=$dir_kb
        case "$dir_path" in
            /tmp/claude-*/*) project=${dir_path##*/-home-lukesh-}
                             name="Temp files of the Claude session in ${project#projects-}" ;;
            *)               name="Files in $dir_path" ;;
        esac
    else
        size=$app_kb
        name="$app_name"
    fi
    echo "$name is using $(awk -v k="$size" 'BEGIN {printf "%.1f", k/1048576}') GB"
}

notify() {   # level title
    if (( $1 == 2 )); then
        notify-send -u critical -a Memory "$2" "$(cause). At 90% of RAM and swap the session gets killed."
    else
        notify-send -u normal -a Memory "$2" "$(cause)"
    fi
}

level=$(rose ram "$ram" "$RAM_WARN" "$RAM_CRIT") && notify "$level" "Memory high: ${ram}%"
level=$(rose swap "$swap" "$SWAP_WARN" "$SWAP_CRIT") && notify "$level" "Free up swap: ${swap}%"
exit 0
