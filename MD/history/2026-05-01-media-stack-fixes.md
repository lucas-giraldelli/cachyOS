# 2026-05-01 — Media Stack: Fixes, Quality Profiles & Subtitle Config

## Summary

Full overhaul of the media stack (Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr, Bazarr, Jellyfin) fixing broken routing, download paths, language profiles, and subtitle automation.

---

## Fixes

### Jellyseerr → Sonarr: root folder wrong

Jellyseerr was sending `rootFolderPath: /data/media/tv` to Sonarr, which only has `/data/media/shows`. Fixed in `settings.json`:

```json
"activeDirectory": "/data/media/shows"
```

### Prowlarr indexers unreachable (network isolation)

`flaresolverr`, `redis`, and `torrent-indexer` had no `networks:` declared in `docker-compose.yml` → defaulted to `media-stack_default`. Prowlarr is on the `shared` network. They couldn't resolve each other by hostname.

Fix: added `networks: - shared` to all three services. Restarted Prowlarr to clear cached DNS failure state.

```yaml
flaresolverr:
  networks:
    - shared

redis:
  networks:
    - shared

torrent-indexer:
  networks:
    - shared
```

### qBittorrent downloading to media root folder

qBittorrent's `Session\DefaultSavePath` was `/data/media` (the library root). Sonarr/Radarr were pointing categories directly at `/data/media/shows` and `/data/media/movies`.

Fix:
- Created `/mnt/main/Media-Stack/data/downloads/` (+ `incomplete/` subdir)
- Added volume `/mnt/main/Media-Stack/data/downloads:/data/downloads` to qBittorrent, Sonarr and Radarr in `docker-compose.yml`
- Updated `qBittorrent.conf`: `Session\DefaultSavePath=/data/downloads`
- Updated `categories.json`: both `tv-sonarr` and `radarr` now point to `/data/downloads`
- Removed duplicate category `tv-sonnar` (typo)

### Sonarr: ghost root folder `/data/media/tv`

Sonarr had a stale root folder entry for `/data/media/tv` (never existed). Removed via Sonarr UI (Settings → Media Management → Root Folders).

### Jellyfin libraries disappeared

After a Jellyfin Sync 401 error, `/config/root/default/` was found empty — all library definitions were gone. The SQLite DB still had 2104 media items. Recreated libraries via Jellyfin UI:

- **Shows** → `/data/media/shows`
- **Movies** → `/data/media/movies`

Jellyfin re-linked existing DB entries on rescan.

### Billy & Mandy movies: wrong metadata in Jellyfin

Folder names use `Billy and Mandy...` but TMDB title uses `Billy & Mandy:...`. Jellyfin couldn't match automatically. Fixed via Jellyfin UI → Identify using TMDB IDs:

- *Wrath of the Spider Queen*: TMDB `463708`
- *Big Boogey Adventure*: TMDB `17305`

---

## Quality Profiles (Sonarr + Radarr)

Replaced the 6 default profiles with 3 unified ones (same IDs on both apps):

| ID | Name | Behavior |
|----|------|----------|
| 7 | PT-BR Primeiro | Prefers PT-BR audio (CF score 100), accepts any language. Max 1080p, upgrades from SD up. |
| 8 | PT-BR Only | Only downloads if PT-BR detected (minFormatScore=100). Max 1080p. |
| 9 | English / Legendado | No language filter. Max 1080p, fallback to lower quality. |

**Custom Format "PT-BR"** created in both apps. Regex:

```
(?i)(\bDUBLADO\b|\bDUAL\b|\bNACIONAL\b|\bPT[-. ]?BR\b|\bPTBR\b|\bPORTUGUES)
```

**Assignments:**

- All 15 series → `English / Legendado`
- Most movies → `English / Legendado`
- PT-BR dubbed animated movies → `PT-BR Only`:
  - Soul, The Princess and the Frog, Hoodwinked Too!, Billy & Mandy: Wrath of the Spider Queen, Billy & Mandy's Big Boogey Adventure

**Jellyseerr** default updated to profile 9 (`English / Legendado`) for both Sonarr and Radarr.

---

## Subtitle Config (Bazarr)

Language profile `PT-BR > EN` (id=2) configured in Bazarr DB:

```json
[
  {"id": 1, "language": "pb"},
  {"id": 2, "language": "en"}
]
```

- Cutoff: 1 (stops upgrading once PT-BR subtitle found)
- Providers active: opensubtitlescom, podnapisi, yifysubtitles, tvsubtitles, wizdom

**Assignments:**

- All 15 series → `PT-BR > EN`
- English movies → `PT-BR > EN`
- PT-BR Only movies (Soul, Princess & Frog, Hoodwinked, Billy & Mandy films) → no profile (already dubbed, no subtitle needed)

**Default profiles enabled** in `config.yaml`:

```yaml
serie_default_enabled: true
serie_default_profile: '2'
movie_default_enabled: true
movie_default_profile: '2'
```

New content added by Sonarr/Radarr will automatically receive the `PT-BR > EN` subtitle profile.
