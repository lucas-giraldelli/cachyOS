#!/usr/bin/env bash
python3 - <<'EOF'
import subprocess, json, os
from datetime import datetime, date
from collections import defaultdict

CACHE_FILE = os.path.expanduser("~/.cache/waybar-calendar.json")

today = date.today()
start = date(today.year, today.month, 1)
end_month = today.month + 2
end_year = today.year + (end_month - 1) // 12
end_month = ((end_month - 1) % 12) + 1
end = date(end_year, end_month, 1)

out = subprocess.check_output(
    ["gcalcli", "agenda", "--nocolor", "--details", "end",
     "--tsv", start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d")],
    stderr=subprocess.DEVNULL
).decode()

by_day = defaultdict(list)
for line in out.strip().splitlines():
    parts = line.split("\t")
    if len(parts) < 5 or parts[0] == "start_date" or not parts[1]:
        continue
    try:
        d = datetime.strptime(parts[0], "%Y-%m-%d").date()
        by_day[str(d)].append([parts[4], parts[1], parts[3]])
    except Exception:
        pass

data = {"updated": datetime.now().isoformat(), "events": dict(by_day)}
os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
with open(CACHE_FILE, "w") as f:
    json.dump(data, f)

print(f"Cache updated: {len(by_day)} days with events")
EOF
