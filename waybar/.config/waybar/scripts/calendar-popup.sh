#!/usr/bin/env bash

if hyprctl clients -j | python3 -c "import sys,json; exit(0 if any(c['title']=='Calendário' for c in json.load(sys.stdin)) else 1)" 2>/dev/null; then
    hyprctl dispatch closewindow title:Calendário
    exit
fi

python3 ~/.config/waybar/scripts/calendar-popup.py &
