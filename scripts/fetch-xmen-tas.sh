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
SHOW_DIR="X-Men - The Animated Series"
SHOW_TITLE="X-Men The Animated Series"

# Season/episode numbers come from Sonarr (TVDB 76115), not from a hardcoded
# table: the archive's EP01..EP76 is a *broadcast* absolute numbering, while
# TVDB counts the "Pryde of the X-Men" pilot as absolute 1. So archive EPnn maps
# to TVDB absolute nn+1, and the season boundaries are TVDB's, not the ones
# published with the upscale.
SONARR_URL="http://localhost:8989"
SONARR_CONFIG="/home/lukesh/media-stack-config/sonarr/config.xml"
SERIES_TVDB=76115
ABS_OFFSET=1

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

# Only one instance may run: two concurrent runs hand the same output file to
# two curls, and `-C -` then resumes each from the other's offset, producing a
# file that is larger than the source and silently corrupt.
LOCK="/tmp/fetch-xmen-tas.lock"
exec 9>"$LOCK"
flock -n 9 || { echo "another run holds $LOCK — aborting" >&2; exit 1; }

# Kill our own curls if we are interrupted, so no orphan keeps writing to a
# file a later run will resume.
cleanup() { rm -rf "${tmp:-}"; pkill -9 -P $$ 2>/dev/null; jobs -p | xargs -r kill -9 2>/dev/null; }
tmp="$(mktemp -d)"
trap cleanup EXIT INT TERM

# --- fetch the item file list ---------------------------------------------
echo ">> fetching file list for $ITEM"
curl -sfL "https://archive.org/metadata/${ITEM}" -o "$tmp/meta.json"

# --- fetch the authoritative episode map from Sonarr ----------------------
echo ">> fetching episode map from Sonarr (tvdb $SERIES_TVDB)"
API_KEY="$(grep -oP '(?<=<ApiKey>)[^<]+' "$SONARR_CONFIG")"
[[ -n "$API_KEY" ]] || { echo "could not read Sonarr API key from $SONARR_CONFIG" >&2; exit 1; }

SERIES_ID="$(curl -sf -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/series" \
  | python3 -c "import json,sys;print(next((s['id'] for s in json.load(sys.stdin) if s['tvdbId']==$SERIES_TVDB),''))")"
[[ -n "$SERIES_ID" ]] || {
  echo "series tvdb $SERIES_TVDB is not in Sonarr yet — add it first" >&2; exit 1; }

curl -sf -H "X-Api-Key: $API_KEY" \
  "$SONARR_URL/api/v3/episode?seriesId=$SERIES_ID" -o "$tmp/sonarr.json"

# --- join archive files to Sonarr episodes on absolute number -------------
python3 - "$tmp/meta.json" "$tmp/sonarr.json" "$EXT" "$ABS_OFFSET" > "$tmp/files.tsv" <<'PY'
import json, re, sys
meta, sonarr, ext, offset = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

by_abs = {e["absoluteEpisodeNumber"]: e
          for e in json.load(open(sonarr)) if e.get("absoluteEpisodeNumber")}

missing = []
for f in json.load(open(meta))["files"]:
    n = f["name"]
    if not n.lower().endswith("." + ext):
        continue
    m = re.match(r"EP(\d+)\s*-\s*(.+)\.\w+$", n)
    if not m:
        continue
    ep = by_abs.get(int(m.group(1)) + offset)
    if ep is None:
        missing.append(n)
        continue
    # Sonarr's title is canonical — it is what the library will end up named as
    title = re.sub(r'[/:]', '-', ep["title"])
    print(f"{ep['seasonNumber']}\t{ep['episodeNumber']}\t{title}\t{n}\t{f.get('size', 0)}")

if missing:
    print("no Sonarr episode for: " + ", ".join(missing), file=sys.stderr)
PY

count=$(wc -l < "$tmp/files.tsv")
[[ "$count" -eq 0 ]] && { echo "no .$EXT files found in item" >&2; exit 1; }
echo ">> $count .$EXT episodes in item"

# --- build the work list (skip seasons not requested / files already done) --
: > "$tmp/queue"
total_bytes=0
while IFS=$'\t' read -r s e title src size; do
  [[ ",${SEASONS}," == *",${s},"* ]] || continue

  seasondir="$(printf '%s/%s/Season %02d' "$DEST_ROOT" "$SHOW_DIR" "$s")"
  # Sonarr-friendly: Title - SxxEyy - Episode Name.ext
  out="$(printf '%s/%s - S%02dE%02d - %s.%s' "$seasondir" "$SHOW_TITLE" "$s" "$e" "$title" "$EXT")"

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
       --no-progress-meter \
       -o "$out" "${BASE}/$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$src")"
}
export -f dl

# shellcheck disable=SC2016
xargs -a "$tmp/queue" -d '\n' -I{} -P "$JOBS" bash -c 'dl "$@"' _ {}

echo
echo ">> done. Import in Sonarr with:"
echo "   Wanted -> Manual Import -> $DEST_ROOT/$SHOW_DIR"
echo "   (series: X-Men: The Animated Series, TVDB 76115)"
