# 2026-06-26 — Jellyfin NVENC Broken After NVIDIA Driver Update (CDI stale uvm major)

## What happened

Two separate failures hit Jellyfin after an NVIDIA driver update (595.x → 610.43.02, built Jun 13):

1. **Container down** (`media.lucasgiraldelli.dev` unreachable) — the `jellyfin` container was stuck in `Exited(255)` and would not start.
2. **After it was started, every playback that required transcoding failed** with "playback error" in the client. The rest of the media stack was fine because only Jellyfin uses the GPU.

Both root causes trace back to the same trigger: an NVIDIA driver update changed dynamic device state that stale config still referenced.

---

## Problem 1 — Container won't start: `Exited(255)`

### Root cause

`docker-compose.yml` bound MIG-only caps devices explicitly:

```yaml
devices:
  - /dev/nvidia-caps/nvidia-cap1:/dev/nvidia-caps/nvidia-cap1
  - /dev/nvidia-caps/nvidia-cap2:/dev/nvidia-caps/nvidia-cap2
```

After the driver update `/dev/nvidia-caps/` was not recreated. Docker validates bind-mount sources **before** the NVIDIA runtime hook runs, so a missing source path aborts the start immediately with:

```
error gathering device information while adding custom device
"/dev/nvidia-caps/nvidia-cap1": no such file or directory
```

These caps are **MIG-only**, and the RTX 4080 has no MIG support (`nvidia-smi --query-gpu=mig.mode.current` → `[N/A]`). NVENC never needed them.

### Emergency fix (if it happens again before the permanent fix is in place)

```bash
nvidia-modprobe -c 0        # setuid root, no sudo needed; recreates /dev/nvidia-caps
docker start jellyfin
```

### Permanent fix (applied)

Removed the `devices:` block from `docker-compose.yml`. With `runtime: nvidia` +
`NVIDIA_DRIVER_CAPABILITIES=compute,video,utility`, the nvidia-container-runtime
injects `nvidia0`/`nvidiactl`/`nvidia-uvm` and recreates/injects the caps itself.
Committed as `e1009fb`.

---

## Problem 2 — Playback error: FFmpeg `exit 187` / `cuInit → CUDA_ERROR_UNKNOWN`

### Symptoms

Jellyfin log on every transcode:

```
MediaBrowser.Common.FfmpegException: FFmpeg exited with code 187
```

Minimal NVENC test inside the container:

```
cu->cuInit(0) failed -> CUDA_ERROR_UNKNOWN: unknown error
```

Confusingly: `nvidia-smi` worked **inside** the container, `libcuda.so` was the
correct version (610.43.02), all device nodes were present, **and the same FFmpeg
NVENC test ran fine on the host.** So host GPU/driver/uvm were healthy — the
problem was container-specific.

### Root cause

The device cgroup of the container was **blocking `/dev/nvidia-uvm`**. Diagnostic:

```bash
docker exec jellyfin dd if=/dev/nvidia-uvm of=/dev/null bs=1 count=0
# dd: failed to open '/dev/nvidia-uvm': Operation not permitted   <-- cgroup block
```

`nvidia0` and `nvidiactl` opened fine; only the uvm device was denied. CUDA needs
`nvidia-uvm` to initialize → `cuInit` fails → exit 187.

Why: the **uvm device major is allocated dynamically** at module load. The driver
update shifted it. The kernel now registers it at **237**:

```bash
grep nvidia-uvm /proc/devices      # 237 nvidia-uvm
ls -la /dev/nvidia-uvm             # host: 237, 0  (correct)
```

But the **CDI spec** used by nvidia-container-toolkit (`mode = "auto"`) was stale,
generated **before** the update (`/etc/cdi/nvidia.yaml`, dated Jun 20) and still
pinned to the old major **235**:

```yaml
- path: /dev/nvidia-uvm
  major: 235          # WRONG — kernel now uses 237
- path: /dev/nvidia-uvm-tools
  major: 235
  minor: 1
```

So the container whitelisted major 235 in its cgroup and created `nvidia-uvm-tools`
as `235,1` (a non-existent device), while the real uvm at `237,0` was blocked.

**Note:** this was NOT caused by the Problem-1 compose change. `docker restart`
and even `docker compose up --force-recreate` did **not** fix it, because both
reuse the stale CDI spec.

### Fix (applied)

Regenerate the CDI spec from current `/proc/devices`, then recreate the container:

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
docker compose -f /home/lukesh/projects/cachyOS/media-stack/Media-Stack/docker-compose.yml \
  up -d --force-recreate jellyfin
```

### Verification

```bash
# uvm opens, no more cgroup block:
docker exec jellyfin dd if=/dev/nvidia-uvm of=/dev/null bs=1 count=0   # 0+0 records in

# full Jellyfin-style pipeline succeeds (empty output = OK):
docker exec jellyfin /usr/lib/jellyfin-ffmpeg/ffmpeg -hide_banner -loglevel error \
  -f lavfi -i testsrc=duration=2:size=1920x1080:rate=30 \
  -init_hw_device cuda=cu:0 -filter_hw_device cu \
  -vf "format=nv12,hwupload_cuda,scale_cuda=1280:720" -c:v h264_nvenc -f null -
```

---

## Recurrence & permanent prevention

Problem 2 **recurs on every driver update that shifts the dynamic uvm major**,
because the CDI spec is not regenerated automatically. Proposed `pacman` hook
(`/etc/pacman.d/hooks/nvidia-cdi-regen.hook`) to regenerate it post-upgrade:

```ini
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = nvidia-utils
Target = nvidia-open*
Target = linux-cachyos-nvidia-open
Target = nvidia-container-toolkit

[Action]
Description = Regenerating NVIDIA CDI spec for container GPU access...
When = PostTransaction
Exec = /usr/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

After installing the hook, also restart GPU containers post-update (the CDI
regen alone fixes new containers; running ones must be recreated).

---

## Quick triage checklist (next time)

1. `docker ps -a | grep jellyfin` — is it `Exited`?
2. If `Exited(255)` with `nvidia-caps ... no such file` → `nvidia-modprobe -c 0`, restart. (Should not recur after `e1009fb`.)
3. If playback fails with FFmpeg `exit 187`:
   - `docker exec jellyfin /usr/lib/jellyfin-ffmpeg/ffmpeg ... h264_nvenc` → `cuInit ... CUDA_ERROR_UNKNOWN`?
   - `docker exec jellyfin dd if=/dev/nvidia-uvm of=/dev/null bs=1 count=0` → `Operation not permitted`?
   - Compare `grep nvidia-uvm /proc/devices` (real major) vs `/etc/cdi/nvidia.yaml` (spec major).
   - Mismatch → `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` + recreate container.
