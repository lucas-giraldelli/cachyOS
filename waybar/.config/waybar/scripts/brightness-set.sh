#!/bin/bash
# $1: up or down
if [ "$1" = "up" ]; then
    ddcutil setvcp 10 + 5
else
    ddcutil setvcp 10 - 5
fi
sleep 0.3
read_val=$(ddcutil getvcp 10 2>/dev/null)
cur=$(echo "$read_val" | grep -oP 'current value =\s*\K\d+')
max=$(echo "$read_val" | grep -oP 'max value =\s*\K\d+')
if [ -n "$cur" ] && [ -n "$max" ]; then
    echo "$cur/$max" > /tmp/waybar-brightness
    pkill -SIGRTMIN+8 waybar
fi
