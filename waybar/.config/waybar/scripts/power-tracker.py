#!/usr/bin/env python3

import time
import json
import os
from datetime import datetime
from pathlib import Path

RAPL_PATH = "/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"
MAX_ENERGY_PATH = "/sys/class/powercap/intel-rapl/intel-rapl:0/max_energy_range_uj"
DATA_DIR = Path("/var/lib/power-tracker")
INTERVAL = 60  # seconds


def read_uj(path):
    with open(path) as f:
        return int(f.read().strip())


def data_file():
    now = datetime.now()
    return DATA_DIR / f"{now.year}-{now.month:02d}.json"


def load_data():
    f = data_file()
    if f.exists():
        with open(f) as fp:
            return json.load(fp)
    return {"kwh": 0.0, "last_uj": None, "last_time": None}


def save_data(data):
    with open(data_file(), "w") as f:
        json.dump(data, f)


def main():
    max_uj = read_uj(MAX_ENERGY_PATH)
    data = load_data()

    while True:
        try:
            now_uj = read_uj(RAPL_PATH)
            now_time = time.monotonic()

            if data["last_uj"] is not None:
                delta = now_uj - data["last_uj"]
                if delta < 0:
                    delta += max_uj  # counter wrapped
                joules = delta / 1_000_000
                data["kwh"] += joules / 3_600_000

            data["last_uj"] = now_uj
            data["last_time"] = now_time
            save_data(data)

        except Exception:
            pass

        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
