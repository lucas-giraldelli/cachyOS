#!/usr/bin/env bash
# Hardlink completed X-Men TAS downloads into the Sonarr library, then rescan.
#
# Downloads and library live on the same filesystem (/mnt/main), so a hardlink
# costs no extra space and leaves the download copy intact — same inode, two
# names. Only files whose size matches the archive.org metadata are linked, so
# this is safe to run while fetch-xmen-tas.sh is still downloading; re-run it
# as more episodes finish.

set -euo pipefail

ITEM="x-men-the-animated-series-1080p-ai-upscale_202204"
SRC="/mnt/main/Media-Stack/data/downloads/X-Men - The Animated Series"
DST="/mnt/main/Media-Stack/data/media/shows/X-Men - The Animated Series"
SONARR_URL="http://localhost:8989"
SONARR_CONFIG="/home/lukesh/media-stack-config/sonarr/config.xml"
SERIES_TVDB=76115

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Expected size per SxxEyy. Comparing against the *set* of all sizes is not
# enough — a corrupt file can coincidentally match some other episode's size,
# which is how a truncated/over-written episode reached the library once.
curl -sfL "https://archive.org/metadata/${ITEM}" -o "$tmp/meta.json"
API_KEY="$(grep -oP '(?<=<ApiKey>)[^<]+' "$SONARR_CONFIG")"
SERIES_ID="$(curl -sf -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/series" \
  | python3 -c "import json,sys;print(next((s['id'] for s in json.load(sys.stdin) if s['tvdbId']==$SERIES_TVDB),''))")"
[[ -n "$SERIES_ID" ]] || { echo "series tvdb $SERIES_TVDB not in Sonarr" >&2; exit 1; }
curl -sf -H "X-Api-Key: $API_KEY" \
  "$SONARR_URL/api/v3/episode?seriesId=$SERIES_ID" -o "$tmp/sonarr.json"

python3 - "$tmp/meta.json" "$tmp/sonarr.json" > "$tmp/sizes" <<'PY'
import json, re, sys
exp = {}
for f in json.load(open(sys.argv[1]))["files"]:
    m = re.match(r"EP(\d+)", f["name"])
    if m and f["name"].endswith(".mp4"):
        exp[int(m.group(1))] = int(f.get("size", 0))
for e in json.load(open(sys.argv[2])):
    a = e.get("absoluteEpisodeNumber")
    if a and (a - 1) in exp:   # archive EPnn == TVDB absolute nn+1
        print(f"S{e['seasonNumber']:02d}E{e['episodeNumber']:02d}\t{exp[a - 1]}")
PY

linked=0 skipped=0 partial=0 corrupt=0
while IFS= read -r -d '' f; do
    rel="${f#"$SRC"/}"
    out="$DST/$rel"

    se="$(grep -oP 'S\d\dE\d\d' <<< "$rel" | head -1)"
    want="$(awk -F'\t' -v k="$se" '$1==k{print $2}' "$tmp/sizes")"
    size="$(stat -c %s "$f")"
    if [[ -z "$want" ]]; then
        echo "!! no expected size for $se ($rel)" >&2; continue
    fi
    if (( size > want )); then
        echo "!! CORRUPT (over-written, $((size - want)) bytes too large): $rel" >&2
        corrupt=$(( corrupt + 1 )); continue
    fi
    if (( size < want )); then
        partial=$(( partial + 1 )); continue
    fi

    if [[ -e "$out" ]]; then
        skipped=$(( skipped + 1 )); continue
    fi

    mkdir -p "$(dirname "$out")"
    ln "$f" "$out"
    linked=$(( linked + 1 ))
done < <(find "$SRC" -type f -name '*.mp4' -print0 | sort -z)

echo ">> linked $linked, already present $skipped, still downloading $partial, corrupt $corrupt"

[[ "$linked" -gt 0 ]] || { echo ">> nothing new; skipping rescan"; exit 0; }

API_KEY="$(grep -oP '(?<=<ApiKey>)[^<]+' "$SONARR_CONFIG")"
SERIES_ID="$(curl -sf -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/series" \
  | python3 -c "import json,sys;print(next((s['id'] for s in json.load(sys.stdin) if s['tvdbId']==$SERIES_TVDB),''))")"

curl -sf -X POST -H "X-Api-Key: $API_KEY" -H 'Content-Type: application/json' \
  -d "{\"name\":\"RescanSeries\",\"seriesId\":$SERIES_ID}" \
  "$SONARR_URL/api/v3/command" > /dev/null
echo ">> RescanSeries queued for series $SERIES_ID"
