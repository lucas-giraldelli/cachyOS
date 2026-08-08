# 2026-08-08 — Jellyfin Down: CDI Spec Poisoned by Partial NVIDIA Upgrade (`nvidia-settings`)

`media.lucasgiraldelli.dev` returned **502** for ~18 hours. Not the arr\* stack —
every other container (sonarr, radarr, prowlarr, qbittorrent, gluetun, bazarr,
jellyseerr) was healthy the whole time. Only `jellyfin` was down, because it is
the only container that touches the GPU.

Same family as [2026-06-26](2026-06-26-jellyfin-nvenc-cdi-uvm.md) — a stale CDI
spec after a driver update — but a **different mechanism**, and one the previously
proposed prevention would not have caught.

---

## Symptoms

```
$ docker ps -a --filter name=jellyfin
jellyfin    Exited (127) 18 hours ago

$ docker logs cloudflared
ERR Unable to reach the origin service ... dial tcp: lookup jellyfin on
    127.0.0.11:53: no such host   originService=http://jellyfin:8096
```

The cloudflared error is a red herring for the cause — `jellyfin` simply had no
DNS entry on the docker network because the container did not exist/run. The real
error only appears on `docker start`:

```
OCI runtime create failed: runc create failed: unable to start container process:
error during container init: failed to fulfil mount request:
open /usr/lib/libnvidia-gtk3.so.610.57.04: no such file or directory
```

Exit code **127** is misleading here — it looks like "command not found" inside
the container, but the container never got that far. It died in `runc` init while
setting up NVIDIA mounts. Jellyfin's own logs end with a **clean, graceful
shutdown** at 19:31 UTC and contain nothing about the failure, because the process
never started again.

---

## Root cause: partial driver upgrade

On 2026-08-07 the system upgraded:

```
[2026-08-07T14:13:53] upgraded nvidia-utils (610.43.02-3 -> 610.57.04-1)
[2026-08-07T14:14:26] upgraded linux-cachyos-nvidia-open (7.0.12-1 -> 7.1.6-1)
```

But **`nvidia-settings` stayed at `610.43.03-1`** — the CachyOS repo had not yet
published `610.57.04` for it. That package owns exactly one file that matters
here:

```
/usr/lib/libnvidia-gtk3.so.610.43.03   <- owned by nvidia-settings 610.43.03
```

At 14:15 the pacman hook regenerated the CDI spec (see next section). The
toolkit's discovery **found the gtk3 lib on disk but wrote the path using the
active driver version** (`610.57.04`, from `nvidia-smi`) rather than the version
in the actual filename. So `/etc/cdi/nvidia.yaml` ended up demanding:

```
/usr/lib/libnvidia-gtk3.so.610.57.04    <- provided by NO package, never existed
```

Every GPU container creation then failed on that missing mount source. The
version-rewriting is inferred from the evidence — gtk3 was the *only* lib on disk
at a non-matching version, and it was the *only* path in the spec that did not
exist — not read out of the toolkit source.

Note that `nvidia-settings` was already skewed *before* this upgrade
(`610.43.03` vs `nvidia-utils 610.43.02`) and nothing broke. The mismatch only
became fatal once the minor version diverged.

---

## Why the June prevention did not help

The 2026-06-26 postmortem proposed adding
`/etc/pacman.d/hooks/nvidia-cdi-regen.hook` to regenerate the CDI spec after
driver upgrades. **That hook was never installed — and it did not need to be.**
`nvidia-container-toolkit` already ships an equivalent one:

```
/usr/share/libalpm/hooks/nvidia-ctk-cdi.hook   (owned by nvidia-container-toolkit)
  Target = nvidia-utils, nvidia-container-toolkit, opencl-nvidia, egl-gbm, egl-wayland
  Exec   = /usr/share/libalpm/scripts/nvidia-ctk-cdi   (PostTransaction)
```

It fired correctly on 2026-08-07 at 14:15 — the spec's mtime proves it. **The
automation worked and still produced a broken spec**, because regeneration is
only as good as the driver files on disk, and those were internally inconsistent.

Lesson: auto-regeneration is necessary but not sufficient. A partial upgrade of
the NVIDIA package set poisons the spec no matter how promptly it is rebuilt.

**Do not add the proposed hook** — it would be a redundant duplicate of the
shipped one.

---

## Fix (applied)

Order matters. Recreating the container first does **not** work — the mount list
is baked from the cached CDI spec at creation time, not rescanned from disk.
`docker compose up -d --force-recreate` was tried and failed identically before
the spec was regenerated.

```bash
# 1. Drop the stale package (GUI-only tool, useless on Wayland/Hyprland,
#    unrelated to NVENC/transcoding)
sudo paru -Rns nvidia-settings

# 2. Regenerate the CDI spec now that no mismatched lib remains
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# 3. Only now recreate the container
cd /mnt/main/Media-Stack
docker compose up -d --force-recreate jellyfin
```

Removing `nvidia-settings` was chosen over symlinking the phantom `.610.57.04`
path: a hand-made file in `/usr/lib` is outside pacman's control and would
conflict on the next upgrade. `nvidia-settings` is an X11-era GTK config GUI with
no role in headless transcoding, and it will come back on its own when the repo
publishes `610.57.04`.

## Verification

```bash
$ grep -c libnvidia-gtk3 /etc/cdi/nvidia.yaml
0

$ docker ps --filter name=jellyfin --format '{{.Status}}'
Up 30 seconds (healthy)

$ curl -o /dev/null -w '%{http_code}\n' https://media.lucasgiraldelli.dev
302                       # normal Jellyfin redirect to /web/

$ docker exec jellyfin nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
NVIDIA GeForce RTX 4080, 610.57.04    # GPU still passed through, NVENC intact
```

---

## Quick triage checklist (next time a GPU container won't start)

1. `docker ps -a | grep jellyfin` — `Exited (127)` with clean app logs means it
   died in `runc` init, **not** in the application. Ignore the app logs.
2. `docker start jellyfin` — the real error only surfaces here, not in
   `docker logs`.
3. If `failed to fulfil mount request: open /usr/lib/libnvidia-*.so.<ver>`:
   ```bash
   nvidia-smi --query-gpu=driver_version --format=csv,noheader   # active driver
   ls /usr/lib/libnvidia-*.so.* | grep -v <that version>         # stragglers
   pacman -Qo <straggler>                                        # who owns it
   ```
4. Any package left on an older driver version → remove or upgrade it, then
   **regenerate the spec before recreating the container**.
5. After *any* NVIDIA upgrade, sanity-check that the whole set moved together:
   ```bash
   pacman -Q | grep -E 'nvidia|opencl-nvidia|egl-' 
   ```
   A version that lags is a latent outage for every GPU container.
