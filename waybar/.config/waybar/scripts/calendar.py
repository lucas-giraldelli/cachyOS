#!/usr/bin/env python3
import sqlite3
import shutil
import json
import glob
import os
from datetime import datetime, timedelta

profiles = glob.glob(os.path.expanduser("~/.thunderbird/*.default-release"))
if not profiles:
    profiles = glob.glob(os.path.expanduser("~/.thunderbird/*/"))
if not profiles:
    print(json.dumps({"text": "󰸗", "tooltip": "Thunderbird não encontrado"}))
    exit()

src = os.path.join(profiles[0], "calendar-data", "cache.sqlite")
tmp = "/tmp/tb_cal_waybar.sqlite"
shutil.copy2(src, tmp)

now = datetime.now()
start_of_day = datetime(now.year, now.month, now.day)
end_of_day = start_of_day + timedelta(days=1)

start_us = int(start_of_day.timestamp()) * 1_000_000
end_us = int(end_of_day.timestamp()) * 1_000_000

conn = sqlite3.connect(tmp)
cur = conn.cursor()

cur.execute("""
    SELECT title, event_start, event_end
    FROM cal_events
    WHERE event_start >= ? AND event_start < ?
    AND ical_status IN ('CONFIRMED', 'TENTATIVE')
    ORDER BY event_start
""", (start_us, end_us))

events = cur.fetchall()
conn.close()
os.unlink(tmp)

date_str = now.strftime("%a %d %b")

if not events:
    print(json.dumps({"text": date_str, "tooltip": "Sem eventos hoje", "class": "calendar-empty"}))
else:
    lines = []
    for title, start, end in events:
        s = datetime.fromtimestamp(start / 1_000_000)
        e = datetime.fromtimestamp(end / 1_000_000)
        lines.append(f"{s.strftime('%H:%M')} – {e.strftime('%H:%M')}  {title}")

    tooltip = "\n".join(lines)
    print(json.dumps({"text": date_str, "tooltip": tooltip, "class": "calendar-events"}))
