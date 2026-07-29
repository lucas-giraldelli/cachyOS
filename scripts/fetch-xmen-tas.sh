#!/usr/bin/env bash
# Download "X-Men: The Animated Series (1992) - 1080p AI Upscale" from archive.org
# and lay it out in a Sonarr-importable structure.
#
# Item: https://archive.org/details/x-men-the-animated-series-1080p-ai-upscale_202204
# The item numbers episodes absolutely (EP01..EP76); this script maps them back to
# SxxEyy using the broadcast season boundaries below.
#
# Usage:
#   ./fetch-xmen-tas.sh                 # MP4 set (~9 GB), 3 concurrent
#   ./fetch-xmen-tas.sh --mkv           # MKV set (~150 GB)
#   ./fetch-xmen-tas.sh --mkv -j2       # 2 concurrent
#   ./fetch-xmen-tas.sh --mkv -s 1,2    # only seasons 1 and 2
#   ./fetch-xmen-tas.sh --list          # dry run, print what would be downloaded
#
# Safe to re-run: curl -C - resumes partial files, completed files are skipped.

set -euo pipefail

ITEM="x-men-the-animated-series-1080p-ai-upscale_202204"
BASE="https://archive.org/download/${ITEM}"
DEST_ROOT="/mnt/main/Media-Stack/data/downloads"
SHOW_DIR="X-Men (1992)"

EXT="mp4"
JOBS=3
SEASONS="1,2,3,4,5"
DRYRUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mkv)      EXT="mkv"; shift ;;
    --mp4)      EXT="mp4"; shift ;;
    -j)         JOBS="$2"; shift 2 ;;
    -j*)        JOBS="${1#-j}"; shift ;;
    -s|--seasons) SEASONS="$2"; shift 2 ;;
    --list)     DRYRUN=1; shift ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
    *)          echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Last absolute episode number of each season (13/13/17/10/23 = 76)
SEASON_END=(13 26 43 53 76)

season_of() {  # absolute ep -> season number
  local ep="$1" s
  for s in 1 2 3 4 5; do
    (( ep <= SEASON_END[s-1] )) && { echo "$s"; return; }
  done
}
ep_in_season() {  # absolute ep -> episode number within its season
  local ep="$1" s prev
  s="$(season_of "$ep")"
  prev=0
  (( s > 1 )) && prev="${SEASON_END[s-2]}"
  echo $(( ep - prev ))
}

# --- fetch the item file list ---------------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo ">> fetching file list for $ITEM"
curl -sfL "https://archive.org/metadata/${ITEM}" -o "$tmp/meta.json"

python3 - "$tmp/meta.json" "$EXT" > "$tmp/files.tsv" <<'PY'
import json, re, sys
meta, ext = sys.argv[1], sys.argv[2]
for f in json.load(open(meta))["files"]:
    n = f["name"]
    if not n.lower().endswith("." + ext):
        continue
    m = re.match(r"EP(\d+)\s*-\s*(.+)\.\w+$", n)
    if not m:
        continue
    print(f"{int(m.group(1))}\t{m.group(2).strip()}\t{n}\t{f.get('size', 0)}")
PY

count=$(wc -l < "$tmp/files.tsv")
[[ "$count" -eq 0 ]] && { echo "no .$EXT files found in item" >&2; exit 1; }
echo ">> $count .$EXT episodes in item"

# --- build the work list (skip seasons not requested / files already done) --
: > "$tmp/queue"
total_bytes=0
while IFS=$'\t' read -r abs title src size; do
  s="$(season_of "$abs")"
  [[ ",${SEASONS}," == *",${s},"* ]] || continue

  e="$(ep_in_season "$abs")"
  seasondir="$(printf '%s/%s/Season %02d' "$DEST_ROOT" "$SHOW_DIR" "$s")"
  # Sonarr-friendly: Title - SxxEyy - Episode Name.ext
  out="$(printf '%s/X-Men (1992) - S%02dE%02d - %s.%s' "$seasondir" "$s" "$e" "$title" "$EXT")"

  if [[ -f "$out" ]] && [[ "$(stat -c %s "$out")" == "$size" ]]; then
    continue  # already complete
  fi
  printf '%s\t%s\t%s\n' "$src" "$out" "$seasondir" >> "$tmp/queue"
  total_bytes=$(( total_bytes + size ))
done < "$tmp/files.tsv"

queued=$(wc -l < "$tmp/queue" || echo 0)
if [[ "$queued" -eq 0 ]]; then
  echo ">> nothing to do — everything already downloaded"
  exit 0
fi

need_gb=$(( total_bytes / 1000000000 ))
avail_gb=$(( $(df -B1 --output=avail "$DEST_ROOT" | tail -1) / 1000000000 ))
echo ">> $queued file(s) to download, ~${need_gb} GB (free on target: ${avail_gb} GB)"

if [[ "$DRYRUN" -eq 1 ]]; then
  cut -f2 "$tmp/queue"
  exit 0
fi

if (( need_gb + 10 > avail_gb )); then
  echo "!! not enough free space (need ~${need_gb} GB + 10 GB headroom, have ${avail_gb} GB)." >&2
  echo "   Use --mp4, or download season by season with -s and let Sonarr import" >&2
  echo "   each batch (which hardlinks/moves it out) before fetching the next." >&2
  exit 1
fi

# --- download, JOBS at a time ---------------------------------------------
export BASE
dl() {
  IFS=$'\t' read -r src out seasondir <<< "$1"
  mkdir -p "$seasondir"
  echo "-> $(basename "$out")"
  # --create-dirs is not enough: curl needs the encoded source name
  curl -fL --retry 5 --retry-delay 5 --retry-all-errors -C - \
       --progress-bar \
       -o "$out" "${BASE}/$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$src")"
}
export -f dl

# shellcheck disable=SC2016
xargs -a "$tmp/queue" -d '\n' -I{} -P "$JOBS" bash -c 'dl "$@"' _ {}

echo
echo ">> done. Import in Sonarr with:"
echo "   Wanted -> Manual Import -> $DEST_ROOT/$SHOW_DIR"
echo "   (series: X-Men (1992), TVDB 71663)"
