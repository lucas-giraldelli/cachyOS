# 2026-07-23 — Steam "unable to open X connection" (systemd-tmpfiles vs. long uptime)

## What happened

Steam refused to start, dying immediately with:

```
Authorization required, but no authorization protocol specified
Unable to open display
Segmentation fault (core dumped)
```

This is a **recurrence** of the XWayland socket problem previously worked
around by the `xwayland-x1-symlink` user unit (see
`2026-05-13-post-update-hyprland-055.md`). The workaround was in place and the
service was `active (running)` — but it had been failing silently for six days.

---

## Root cause

**`systemd-tmpfiles-clean.service` garbage-collects the files of a live X
session once the uptime exceeds 10 days.**

The stock `/usr/lib/tmpfiles.d/x11.conf` ships:

```
D! /tmp/.X11-unix 1777 root root 10d
```

and `/usr/lib/tmpfiles.d/tmp.conf` ships `q /tmp 1777 root root 10d`. The
cleanup timer runs **daily** and has no idea whether the X session owning those
files is still alive — it only looks at file age. Uptime at the time of the
failure was **4 weeks and 3 days**, with XWayland running since 21 Jun.

So the still-running session's socket got deleted out from under it.

### Why the workaround service could not heal it

After the cleanup deleted `/tmp/.X11-unix/X1`, something recreated it on 17 Jul
as a **root-owned socket**:

```
srwxrwxrwx  1 root   root   0 jul 17 11:52 X1     <-- dead, root-owned
srw-rw-rw-  1 lukesh lukesh 0 jun 21 14:05 X1_    <-- the live XWayland socket
```

`/tmp` has the sticky bit, so user `lukesh` cannot remove a file owned by
`root`. The unit's `ln -sf` therefore failed every 3 seconds:

```
ln: failed to create symbolic link '/tmp/.X11-unix/X1': Operation not permitted
```

The service reported `active (running)` the whole time — the failure was only
visible in its journal, which nothing was watching.

---

## Recovery (what actually fixed it)

Two separate problems had to be undone, in order.

**1. Remove the stale root-owned socket** (requires root, sticky bit):

```bash
sudo rm -f /tmp/.X11-unix/X1
```

The symlink service then recreated the link within 3 seconds. This fixed the
socket but Steam still failed — now on the authorization error rather than the
connection error.

**2. Restart the session.** The X authority cookie for the running XWayland was
gone and is **unrecoverable**: the server holds it only in memory, and clients
need the on-disk file to authenticate. Already-connected clients (17 XWayland
windows) kept working because they authenticated before the deletion; no new
client could connect.

```bash
uwsm stop     # session is uwsm-managed; now bound to ALT SHIFT + Q
```

After logging back in, XWayland came up fresh on `:0` with both `X0` and `X0_`
present and owned by the user, and Steam started normally.

---

## Fixes applied

### 1. Stop tmpfiles from aging out live X session files

New `/etc/tmpfiles.d/x11.conf` (tracked at `system/etc/tmpfiles.d/x11.conf`)
overrides the stock file by filename, changing the age field to `-` (never):

```
D! /tmp/.X11-unix 1777 root root -
D! /tmp/.ICE-unix 1777 root root -
D! /tmp/.XIM-unix 1777 root root -
D! /tmp/.font-unix 1777 root root -
```

These live on tmpfs and are cleared on reboot anyway, so there is nothing to
gain from aging them.

Install with:

```bash
sudo install -Dm644 ~/projects/cachyOS/system/etc/tmpfiles.d/x11.conf /etc/tmpfiles.d/x11.conf
systemd-tmpfiles --cat-config | grep X11-unix   # verify the override wins
```

### 2. Generalize the symlink service

The old `xwayland-x1-symlink.service` hardcoded `X1`. After the session restart
the display was `:0`, so the unit was polling a socket that no longer existed —
it would have been dead weight on the next recurrence.

Replaced by `xwayland-socket-symlink.service` +
`scripts/scripts/xwayland-socket-symlink.sh`, which:

- discovers the display number at runtime by globbing `/tmp/.X11-unix/X*_`
- skips the case where `X<N>` already exists as a real socket (nothing to fix)
- **logs a clear message** when the plain socket is a leftover owned by another
  user, naming the `sudo rm -f` needed, instead of looping on a silent
  `Operation not permitted`

The script lives in a file rather than inline in `ExecStart` because systemd
tries to expand `${sock%_}` as its own variable and refuses to start the unit:

```
Invalid environment variable name evaluates to an empty string: sock%_
```

### 3. Logout keybind

`ALT SHIFT + Q` → `uwsm stop`. There was no exit binding at all, and session
restart is the recovery path for a stale XWayland.

---

## Open question

The X authority cookie has **no file on disk** in this setup — not in
`~/.Xauthority`, not in `/run/user/1000`, not in `/tmp/xauth_*` — yet Steam
authenticates fine after a fresh login. So Hyprland 0.55 passes the credential
by some other mechanism, and the initial theory that tmpfiles deleted the
cookie does not hold.

Note that `/usr/lib/tmpfiles.d/sddm.conf` already protects `/tmp/xauth_*` from
aging (`X /tmp/xauth_*`), so that path was never at risk to begin with. The
`x /tmp/xauth_*` line kept in our override is redundant but harmless.

What **is** confirmed is the socket half: `/tmp/.X11-unix` aged at 10d is what
breaks a long-uptime session, and that is what the override prevents.

---

## Symptom → cause quick reference

| Symptom | Meaning |
|---|---|
| `unable to open X connection` | the socket at `/tmp/.X11-unix/X<N>` is missing or dead |
| `Authorization required, but no authorization protocol specified` | socket is fine, the auth cookie is gone — **session restart required** |
| `ln: ... Operation not permitted` in the unit's journal | stale socket owned by another user; `sudo rm -f` it |
| happens after ~10+ days of uptime | tmpfiles cleanup — the override should now prevent this |
