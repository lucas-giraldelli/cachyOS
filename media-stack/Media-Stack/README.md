# Media Stack

Self-hosted media automation stack (Jellyfin + *arr) running via Docker Compose.

## Trackers

- **Samaritano** — private tracker. We now maintain a seed/ratio here, so **do not
  bulk-remove torrents**: removing a torrent that hasn't met the tracker's minimum
  seed time / ratio can trigger a Hit & Run penalty. Check `ratio` and `seeding_time`
  before deleting anything under a `radarr` / `tv-sonarr` category.
  Grabs from Samaritano are currently **manual** (no Prowlarr indexer): download the
  `.torrent`, add it to the stack qBittorrent (`http://localhost:8081`) with the
  right category, and Radarr/Sonarr import it automatically.

## Layout (TRaSH-guides)

Single `/data` volume is mounted into Radarr/Sonarr/qBittorrent so imports use
**hardlinks** (same mount point → no `EXDEV`, no doubled disk usage). Splitting
`/data/media` and `/data/downloads` into separate binds breaks hardlinking — keep
them under one `/data` mount.

```
/mnt/main/Media-Stack/data
├── downloads/            # qBittorrent save path (/data/downloads)
└── media/
    ├── movies/           # Radarr root folder
    └── shows/            # Sonarr root folder (NOT "tv" — keep all series here)
```

## Services

| Service | Port | Notes |
|---------|------|-------|
| Jellyfin | 8096 | NVENC on RTX 4080. Breaks on NVIDIA driver updates — regenerate the CDI spec. |
| Radarr | 7878 | Movies. Category `radarr`. |
| Sonarr | 8989 | TV. Category `tv-sonarr`. Root folder `/data/media/shows`. |
| Prowlarr | 9696 | Indexers. |
| Bazarr | 6767 | Subtitles. |
| Jellyseerr | 5055 | Requests/discovery. |
| qBittorrent | 8081 | Download client (admin login). Save path `/data/downloads`. |
| Flaresolverr | 8191 | Cloudflare bypass for the indexer. |
| torrent-indexer | 7006 | Custom Torznab indexer for BR sites (felipemarinho97). |
| cloudflared | — | Cloudflare Tunnel for remote access. |

## Config

App config lives outside the repo at `/home/lukesh/media-stack-config/<service>`
(on SSD, not the NTFS data drive). The `.env` holds `TUNNEL_TOKEN`.
