# Cloudflare Tunnel — Remote Access for Jellyfin & Jellyseerr

Exposes Jellyfin and Jellyseerr remotely via `lucasgiraldelli.dev` subdomains using Cloudflare Tunnel. No port forwarding, no changes to the modem, works behind ISP-managed routers and CGNAT.

**Portfolio at `lucasgiraldelli.dev` is not affected** — only new subdomains are added.

---

## Phase 1 — Connect the domain to Cloudflare

> One-time setup. The domain stays registered at Hostinger; only DNS management moves to Cloudflare.

1. Create a free account at [cloudflare.com](https://cloudflare.com)
2. Dashboard → **Add a domain** → type `lucasgiraldelli.dev` → select plan **Free** → Continue
3. Cloudflare scans existing DNS records. **Before proceeding**, verify that the portfolio records are present:
   - `lucasgiraldelli.dev` → A record pointing to Hostinger's IP
   - `www.lucasgiraldelli.dev` → A or CNAME pointing to Hostinger
   - Add any missing records manually at this step
4. Cloudflare assigns two nameservers (e.g., `ada.ns.cloudflare.com`, `bob.ns.cloudflare.com`)
5. At Hostinger: **Domains → Manage → DNS / Nameservers** → replace current nameservers with the two from Cloudflare
6. Wait for propagation (~10 min to a few hours). Cloudflare sends an email when the domain is **Active**

---

## Phase 2 — Create the Tunnel

1. Cloudflare dashboard → **Zero Trust** → **Networks → Tunnels → Create a tunnel**
2. Connector type: **Cloudflared**
3. Name: `home-media` → Save
4. Copy the **token** shown on screen (long base64 string) — save it somewhere safe

---

## Phase 3 — Add cloudflared to Docker Compose

Create `/mnt/main/Media-Stack/.env`:

```env
TUNNEL_TOKEN=paste_your_token_here
```

Add the `cloudflared` service to `docker-compose.yml`:

```yaml
cloudflared:
  image: cloudflare/cloudflared:latest
  container_name: cloudflared
  restart: unless-stopped
  command: tunnel --no-autoupdate run --token ${TUNNEL_TOKEN}
  environment:
    - TUNNEL_TOKEN=${TUNNEL_TOKEN}
  networks:
    - shared
```

Start the container:

```bash
cd /mnt/main/Media-Stack
docker compose up -d cloudflared
docker logs cloudflared
# Should show: "Connection registered" and "Registered tunnel connection"
```

The tunnel should appear as **Healthy** in the Cloudflare dashboard.

---

## Phase 4 — Configure public hostnames

In the Cloudflare dashboard → Zero Trust → Networks → Tunnels → click `home-media` → **Public Hostnames** → Add a public hostname:

| Subdomain | Domain | Type | URL |
|-----------|--------|------|-----|
| `media` | `lucasgiraldelli.dev` | HTTP | `jellyfin:8096` |
| `catalog` | `lucasgiraldelli.dev` | HTTP | `jellyseerr:5055` |

> Cloudflare creates the CNAME DNS records automatically. No manual DNS changes needed.

Access from anywhere:
- `https://media.lucasgiraldelli.dev`
- `https://catalog.lucasgiraldelli.dev`

---

## Phase 5 — Security (optional)

Both Jellyfin and Jellyseerr have their own login systems, which is sufficient for personal use. If you want an extra layer before anyone reaches the login screen, Cloudflare Zero Trust → Access → Applications supports email OTP authentication on top.

---

## Directory structure

```
/mnt/main/Media-Stack/
├── .env                  # TUNNEL_TOKEN (never commit this)
└── docker-compose.yml    # cloudflared service added
```

---

## Troubleshooting

```bash
# Check tunnel status
docker logs cloudflared

# Restart after token change
docker compose restart cloudflared

# Verify tunnel is healthy
# Cloudflare dashboard → Zero Trust → Networks → Tunnels
```

Common issues:
- **Tunnel offline**: check `.env` has the correct token and container is on the `shared` network
- **502 Bad Gateway**: service name in the hostname config doesn't match the Docker container name
- **Portfolio broken after nameserver change**: a DNS record was missing — add it manually in Cloudflare DNS dashboard
