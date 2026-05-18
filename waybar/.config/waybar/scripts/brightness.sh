#!/bin/bash
TMPFILE=/tmp/waybar-brightness
if [ ! -f "$TMPFILE" ]; then
    read_val=$(ddcutil getvcp 10 2>/dev/null)
    cur=$(echo "$read_val" | grep -oP 'current value =\s*\K\d+')
    max=$(echo "$read_val" | grep -oP 'max value =\s*\K\d+')
    [ -n "$cur" ] && echo "$cur/$max" > "$TMPFILE"
fi
val=$(cat "$TMPFILE" 2>/dev/null)
cur=${val%%/*}
max=${val##*/}
echo "{\"text\": \"󰃟  ${cur} / ${max}\", \"tooltip\": \"Brilho: ${cur} / ${max}\"}"
