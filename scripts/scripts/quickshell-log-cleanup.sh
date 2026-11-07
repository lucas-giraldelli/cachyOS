#!/usr/bin/env bash
# Quickshell keeps a log dir per instance in $XDG_RUNTIME_DIR/quickshell/by-id and
# never removes it. Every smart-shell restart leaves one behind, and on a long
# uptime they fill the runtime tmpfs (4.6 GB on 2026-11-06), which breaks
# uwsm-app ("No space left on device", then "Invalid arguments").
# Removes the dirs no running qs process has open. Dirs younger than 10 minutes
# are kept, so an instance that is still starting up is never touched.
set -euo pipefail

base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-id"
[ -d "$base" ] || exit 0

declare -A live=()
for pid in $(pgrep -x qs || true); do
    for fd in /proc/"$pid"/fd/*; do
        target=$(readlink "$fd" 2>/dev/null) || continue
        [[ "$target" == "$base"/* ]] || continue
        rel="${target#"$base"/}"
        live["${rel%%/*}"]=1
    done
done

removed=0
while IFS= read -r -d '' dir; do
    id="${dir##*/}"
    [ -n "${live[$id]:-}" ] && continue
    rm -rf -- "$dir"
    removed=$((removed + 1))
done < <(find "$base" -mindepth 1 -maxdepth 1 -type d -mmin +10 -print0)

echo "removed $removed dead quickshell instance dirs"
