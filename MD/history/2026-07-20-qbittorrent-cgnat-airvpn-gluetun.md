# 2026-07-20 — qBittorrent "Seeding but Not Connectable" (ISP CGNAT → AirVPN via gluetun)

## What happened

Seeding on the private tracker (**Samaritano**) suddenly stopped overnight:
qBittorrent was still running and announcing, but the tracker flagged the
client as **not connectable** ("Sua porta ainda não está acessível"). External
peers could not open connections to the listen port, so uploads effectively
stopped even though the client showed as seeding.

The ISP claimed nothing changed on their side. The rest of the setup
(`media.lucasgiraldelli.dev` via Cloudflare Tunnel, Jellyfin) kept working
perfectly — which was the key clue.

---

## Root cause

The connection was moved **behind CGNAT** (Carrier-Grade NAT) by the ISP. Under
CGNAT there is no dedicated public IPv4 and no inbound path — router port
forwarding has no effect and inbound peer/tracker connections are impossible.

### Why the website kept working but seeding didn't

Direction of connection is everything:

| Service | Direction | Broken by CGNAT? |
|---|---|---|
| Site / Jellyfin via Cloudflare Tunnel | **outbound** (cloudflared dials out) | ❌ no |
| BitTorrent seeding | **inbound** (peers/tracker dial in) | ✅ yes |

CGNAT only blocks **inbound**. Everything outbound (browsing, tunnels, VPN)
is unaffected. That asymmetry is why the site was fine and seeding died.

### Evidence gathered

```bash
# Public IP is a shared carrier IP, private hops right after the gateway:
curl -s https://api.ipify.org            # 24.152.34.114
tracepath -n 1.1.1.1                      # hop 1: 192.168.100.1 (router)
                                          # hop 2+: 10.110.20.1, 10.100.100.21 ...  <-- ISP CGNAT space
```

The Samaritano help doc itself lists the `10.0.0.0–10.255.255.255` range on the
WAN path as a CGNAT indicator — matched exactly.

---

## Things ruled out (in order)

1. **qBittorrent health** — fine. Listening correctly; restart changed nothing.
2. **UPnP / NAT-PMP** — dead end. qBittorrent runs in a **docker bridge**
   (`172.19.0.9`); the UPnP discovery multicast never leaves the docker network,
   so it can't reach the real ISP router. No IGD found, no mapping made.
3. **ISP throttling/blocking port 6881** — ruled out. Changed the listen port to
   a high random port (`57209`) and re-tested externally → still unreachable.
   A brand-new port being unreachable proves the block is path-wide, not
   port-specific.
4. **Router port-forward / DHCP lease drift** — could not be inspected or fixed:
   the router is **ISP-managed** (no admin credentials).

With router access impossible and a new port also unreachable, the diagnosis
collapsed to CGNAT. Both remaining fixes (public IP, or a forward) require router
access the user doesn't have → the only path left is an **outbound tunnel**.

### GOTCHA — qBittorrent 5.x listen port lives in TWO keys

Changing `Connection\PortRangeMin` (legacy, `[Preferences]`) had **no effect** —
qBittorrent kept listening on the old port. The real key in v5.x is
`Session\Port` under `[BitTorrent]`. Set **both** (and stop the container first,
or qBittorrent rewrites the config on clean shutdown and reverts the edit):

```ini
[BitTorrent]
Session\Port=49781
[Preferences]
Connection\PortRangeMin=49781
```

---

## Fix (applied)

Route **only qBittorrent** through a VPN with port forwarding, via **gluetun**.
Chose **AirVPN** (€7/mo) — Samaritano's own doc treats VPN-with-port-forward as a
valid fix, and AirVPN has one of the best port-forward implementations. (Surfshark
/ Nord / Express were rejected: no port forwarding = doesn't solve it.)

**Rejected alternatives:** asking the ISP for a public IPv4 (they quoted a steep
price hike); Oracle Cloud Free VM + WireGuard/rathole reverse tunnel (free,
self-owned — kept as the fallback if AirVPN ever fails).

### docker-compose.yml — new gluetun gateway + qBittorrent behind it

```yaml
  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add: [NET_ADMIN]
    devices: [/dev/net/tun:/dev/net/tun]
    environment:
      - VPN_SERVICE_PROVIDER=airvpn
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY}
      - WIREGUARD_PRESHARED_KEY=${WIREGUARD_PRESHARED_KEY}
      - WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES}
      - SERVER_COUNTRIES=Brazil
      - FIREWALL_VPN_INPUT_PORTS=${FORWARDED_PORT}          # AirVPN forwarded port
      - FIREWALL_OUTBOUND_SUBNETS=172.19.0.0/16,192.168.100.0/24  # LAN + docker net for WebUI
      - TZ=America/Cuiaba
    ports:
      - 8081:8081                                           # qBit WebUI via gluetun netns
    networks:
      shared:
        aliases: [qbittorrent]        # Sonarr/Radarr/Prowlarr keep reaching qBit by name

  qbittorrent:
    # ...
    network_mode: "service:gluetun"   # all traffic through the tunnel; no own ports/network
    depends_on:
      gluetun: { condition: service_healthy }
```

WireGuard creds + `FORWARDED_PORT=49781` live in `.env` (gitignored). Committed as
`da9a72f`.

### AirVPN panel setup (manual, one-time)

1. **Config Generator → WireGuard** → pick a Brazil server → download `.conf`
   (gives `PrivateKey`, `Address`, `PresharedKey`).
2. **Client Area → Forwarded Ports → Add** (leave port blank → it assigns one,
   here **49781**, TCP+UDP). This is qBittorrent's listen port **and**
   `FIREWALL_VPN_INPUT_PORTS`.

---

## Verification

```bash
# gluetun healthy, exit IP is AirVPN:
docker exec gluetun wget -qO- https://ipinfo.io/ip     # 146.70.248.10 (AirVPN)

# qBit listens on 49781 inside the tunnel namespace:
docker exec qbittorrent netstat -tlnp | grep 49781     # 10.189.158.193:49781 LISTEN

# EXTERNAL reachability — test the AirVPN IP, NOT the home IP:
python3 -c "import socket;s=socket.socket();s.settimeout(10);print(s.connect_ex(('146.70.248.10',49781)))"
# 0  -> reachable ✓

# WebUI + arr connectivity unchanged:
curl -so /dev/null -w '%{http_code}\n' http://localhost:8081          # 200
docker exec sonarr curl -so /dev/null -w '%{http_code}\n' http://qbittorrent:8081  # 200
```

Result: **connectable restored**, seeding resumed on `146.70.248.10:49781`.

### GOTCHA — home-IP port check will ALWAYS say false now (and that's correct)

```bash
curl https://ifconfig.co/port/49781      # {"ip":"24.152.34.114","reachable":false}  <-- EXPECTED
```

The port lives on the **AirVPN** IP now, not the home IP. Test the VPN IP
(python `connect_ex` above) or AirVPN's **"Test open"** button. Do **not** chase
a `false` on the home IP — it will never be true under CGNAT.

---

## Recurrence #1 — 2026-07-22: VPN flap → qBittorrent loses `tun0`

Seeding died again. **Not CGNAT, not AirVPN, not a dropped forwarded port** — the
tunnel was perfectly healthy the whole time, which is exactly why the original
triage checklist below missed it (steps 1–2 pass, and you stop looking).

### What happened

At 06:06 gluetun restarted the VPN **3×** in three minutes — the healthcheck
timed out right after the handshake, before MTU discovery settled:

```
WARN [vpn] restarting VPN because it failed to pass the healthcheck: startup check:
  dialing: dial tcp4 104.16.132.229:443: i/o timeout
INFO [MTU discovery] reverting VPN interface tun0 MTU to 1320 (PMTUD failed)
...
INFO [MTU discovery] setting VPN interface tun0 MTU to maximum valid MTU 1440   <- settled
```

Every VPN restart **destroys and recreates `tun0`** (it came back at ifindex 6).
qBittorrent had been up since 07-20 and libtorrent only **enumerates interface
addresses at startup** — it never re-binds to the new `tun0`. Result:

```bash
docker exec gluetun ip -4 addr        # tun0 = 10.189.158.193/32  (exists!)
docker exec qbittorrent netstat -tlnp | grep 49781
# 172.19.0.9:49781   LISTEN     <- docker bridge only
# 127.0.0.1:49781    LISTEN
# ::1:49781          LISTEN
#                               <- tun0 MISSING
```

qBit was listening on the bridge; peers arrive on `tun0`; nobody answers.
External test returned `111` (connection refused) and the tracker flagged
not-connectable — with a green, healthy tunnel sitting right there.

### GOTCHA — "gluetun healthy" does NOT mean "qBittorrent is reachable"

These are two independent facts. Always check **which address** qBit is bound to,
not just that the tunnel is up. A missing `tun0` line in `netstat` is the tell.

### Fix (applied)

1. Immediate: `docker compose restart qbittorrent` → re-bound to
   `10.189.158.193:49781`, external test back to `0`.
2. Permanent: bind by **interface name** instead of enumerated address, so a
   recreated `tun0` is picked up automatically. In `qBittorrent.conf`
   (stop the container first — see the shutdown-rewrite gotcha above):

```ini
[BitTorrent]
Session\Interface=tun0
Session\InterfaceName=tun0
Session\InterfaceAddress=
```

Desirable side effect: qBit now binds **only** to `tun0`. If the tunnel
disappears entirely it listens nowhere at all, instead of falling back to the
docker bridge — a stronger kill-switch.

Post-fix verification:

```
LISTEN 10.189.158.193:49781                      # tunnel only, bridge gone ✓
connect_ex(146.70.248.10, 49781) -> 0            # reachable ✓
webui 200 | sonarr/radarr/prowlarr -> qbit 200   # unchanged ✓
```

### Still open

The gluetun VPN flap itself was **not** fixed — it will recur. The startup
healthcheck fires before MTU settles. Mitigation not yet applied:
`HEALTH_VPN_DURATION_INITIAL=30s` in the gluetun environment. With the
interface binding above, a flap is now survivable either way.

---

## Recurrence & things to watch

- **AirVPN subscription expiry** (1-month plan). If it lapses, the tunnel drops,
  the kill-switch cuts qBittorrent's network, and the tracker goes not-connectable
  again. Renew, or the seed silently dies.
- **If it "breaks" again**, check the VPN first before touching anything else:
  ```bash
  docker logs gluetun | tail        # is the tunnel up?
  docker compose restart gluetun    # usually all it needs
  ```
- **Fallback if AirVPN is ever unusable**: Oracle Cloud Free VM + WireGuard/rathole
  reverse tunnel (free, dedicated IP — less likely to be flagged than a shared VPN IP).
- **Don't spam force-reannounce** — the tracker rate-limits it. One announce, or
  wait for the automatic one.
- **Hit & Run**: now that seeding counts again, respect `ratio` / `seeding_time`
  before removing any Samaritano torrent (see media-stack README).

---

## Quick triage checklist (next time "not connectable")

1. `docker logs gluetun | tail` — tunnel connected? If not → `docker compose restart gluetun`.
2. `docker exec gluetun wget -qO- https://ipinfo.io/ip` — is the exit an AirVPN IP?
3. `docker exec qbittorrent netstat -tlnp | grep <port>` — qBit listening on the
   forwarded port **and bound to the `tun0` address**? Compare against
   `docker exec gluetun ip -4 addr`. If the `10.x` tun0 line is missing and you
   only see `172.19.0.9` (bridge), the VPN flapped and qBit didn't re-bind →
   `docker compose restart qbittorrent`. See Recurrence #1. **A healthy gluetun
   does not rule this out — it's the most likely cause when everything looks fine.**
4. Confirm `Session\Port` (`[BitTorrent]`) in `qBittorrent.conf` == AirVPN forwarded port == `FORWARDED_PORT` in `.env`.
5. External test the **AirVPN IP**, not the home IP: `python3 -c "import socket;s=socket.socket();s.settimeout(10);print(s.connect_ex(('<vpn_ip>',<port>)))"` → `0` = open.
6. Still failing? AirVPN forwarded port may have been dropped — re-add it in Client Area → Forwarded Ports, update `FORWARDED_PORT` + qBit listen port to match.
