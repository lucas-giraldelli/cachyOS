#!/usr/bin/env python3
"""
Detects stalled torrents in qBittorrent and removes+blocklists them in Radarr/Sonarr.
- stalledDL with 0 seeds in the swarm + no activity for 30min → blocklist right away
- stalledDL with seeds in the swarm but no activity for 2h → blocklist

Credentials come from the environment (see arr-stall-requeue.service, which
loads the gitignored .env next to this script): QBIT_USER, QBIT_PASS, RADARR_KEY, SONARR_KEY.
"""

import json, os, urllib.request, urllib.parse, http.cookiejar, time, logging
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
log = logging.getLogger(__name__)

QBIT_URL  = "http://localhost:8081"
QBIT_USER = os.environ.get("QBIT_USER", "admin")
QBIT_PASS = os.environ["QBIT_PASS"]

RADARR_URL = "http://localhost:7878"
RADARR_KEY = os.environ["RADARR_KEY"]

SONARR_URL = "http://localhost:8989"
SONARR_KEY = os.environ["SONARR_KEY"]

STALL_NO_SEEDS_SECS  = 30 * 60    # 30 min with no seeds in the swarm → blocklist
STALL_WITH_SEEDS_SECS = 2 * 60 * 60  # 2h with seeds but never connecting → blocklist


def qbit_login():
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    data = urllib.parse.urlencode({'username': QBIT_USER, 'password': QBIT_PASS}).encode()
    opener.open(f"{QBIT_URL}/api/v2/auth/login", data)
    return opener


def qbit_stalled(opener):
    resp = opener.open(f"{QBIT_URL}/api/v2/torrents/info")
    torrents = json.load(resp)
    now = time.time()
    stalled = []
    for t in torrents:
        if t['state'] != 'stalledDL':
            continue
        inactive_secs = now - t['last_activity']
        seeds_in_swarm = t['num_complete']
        threshold = STALL_NO_SEEDS_SECS if seeds_in_swarm == 0 else STALL_WITH_SEEDS_SECS
        if inactive_secs >= threshold:
            stalled.append({
                'hash': t['hash'],
                'name': t['name'],
                'seeds_swarm': seeds_in_swarm,
                'inactive_min': int(inactive_secs // 60),
            })
    return stalled


def arr_queue(base_url, api_key, extra_param=""):
    url = f"{base_url}/api/v3/queue?pageSize=200&includeUnknownItems=true{extra_param}"
    req = urllib.request.Request(url, headers={'X-Api-Key': api_key})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp).get('records', [])


def arr_blocklist(base_url, api_key, ids):
    if not ids:
        return
    data = json.dumps({
        'ids': ids,
        'removeFromClient': True,
        'blocklist': True,
        'skipRedownload': False,
    }).encode()
    req = urllib.request.Request(
        f"{base_url}/api/v3/queue/bulk",
        data=data,
        headers={'X-Api-Key': api_key, 'Content-Type': 'application/json'},
        method='DELETE'
    )
    with urllib.request.urlopen(req):
        pass


def process_arr(name, base_url, api_key, stalled_hashes, extra_param=""):
    queue = arr_queue(base_url, api_key, extra_param)
    to_remove = []
    for item in queue:
        if item.get('downloadId', '').lower() in stalled_hashes:
            to_remove.append(item['id'])
            log.info(f"[{name}] blocklisting: {item['title'][:70]}")
    if to_remove:
        arr_blocklist(base_url, api_key, to_remove)
        log.info(f"[{name}] {len(to_remove)} item(s) removed and blocklisted")
    return len(to_remove)


def main():
    log.info("=== arr-stall-requeue starting ===")
    try:
        opener = qbit_login()
    except Exception as e:
        log.error(f"Failed to connect to qBittorrent: {e}")
        return

    stalled = qbit_stalled(opener)
    if not stalled:
        log.info("No stalled torrent met the criteria.")
        return

    for t in stalled:
        log.info(f"Stalled: {t['name'][:60]} | seeds_swarm={t['seeds_swarm']} | inactive={t['inactive_min']}min")

    stalled_hashes = {t['hash'].lower() for t in stalled}

    total = 0
    total += process_arr("Radarr", RADARR_URL, RADARR_KEY, stalled_hashes,
                         "&includeUnknownMovieItems=true")
    total += process_arr("Sonarr", SONARR_URL, SONARR_KEY, stalled_hashes,
                         "&includeUnknownSeriesItems=true")

    log.info(f"=== Done: {total} item(s) recycled ===")


if __name__ == "__main__":
    main()
