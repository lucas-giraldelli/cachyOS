# Media Stack

A self-hosted media automation stack running via Docker Compose on the local NAS at `/mnt/main/Media-Stack`.

## Services

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Jellyfin | 8096 | `jellyfin.local` | Media server (movies & TV) |
| Radarr | 7878 | `radarr.local` | Movie collection manager |
| Sonarr | 8989 | `sonarr.local` | TV show collection manager |
| Prowlarr | 9696 | `prowlarr.local` | Indexer/tracker manager |
| Bazarr | 6767 | `bazarr.local` | Subtitle downloader |
| Jellyseerr | 5055 | `jellyseerr.local` | Media request & discovery UI |
| qBittorrent | 8081 | `qbit.local` | Torrent download client |
| Flaresolverr | 8191 | — | Cloudflare bypass for indexers |
| torrent-indexer | 7006 | — | Custom Brazilian torrent indexer |
| Redis | — | — | In-memory cache for torrent-indexer |

All services (except Flaresolverr, Redis, and torrent-indexer) are exposed via **Traefik** on a `shared` external Docker network using `.local` hostnames.

## Directory Layout

```
/mnt/main/Media-Stack/
├── docker-compose.yml
├── config/
│   ├── jellyfin/       # Jellyfin config + database
│   ├── radarr/
│   ├── sonarr/
│   ├── prowlarr/
│   ├── bazarr/
│   ├── jellyseerr/
│   ├── qbittorrent/
│   └── adguard/        # AdGuard config (separate service)
└── data/
    ├── media/
    │   ├── movies/     # Radarr-managed movies
    │   └── shows/      # Sonarr-managed TV shows
    └── manual/         # Manual imports (Radarr/Sonarr scan this)
```

## Jellyfin Hardware Transcoding

Jellyfin uses NVIDIA NVENC (RTX 4080) for hardware-accelerated transcoding:

```yaml
environment:
  - NVIDIA_VISIBLE_DEVICES=all
  - NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

Requires the `nvidia-container-toolkit` package and the Docker daemon configured to use the NVIDIA runtime.

## Data Flow

```
Jellyseerr (request) → Radarr/Sonarr (manage) → Prowlarr (find) → qBittorrent (download)
                                                        ↑
                                              torrent-indexer + Flaresolverr
                                              (custom Brazilian indexer via Redis cache)
Bazarr runs alongside → pulls subtitles for everything in /data/media
```

## Common Operations

```bash
# Start the stack
cd /mnt/main/Media-Stack
docker compose up -d

# Check status
docker compose ps

# View logs for a service
docker compose logs -f jellyfin

# Restart a single service
docker compose restart radarr

# Stop everything
docker compose down
```

## Traefik Integration

All services use the `shared` external Docker network and expose `.local` hostnames via Traefik labels. The `shared` network must exist before starting the stack:

```bash
docker network create shared
```
