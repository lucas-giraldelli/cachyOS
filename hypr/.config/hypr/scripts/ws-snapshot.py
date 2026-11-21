#!/usr/bin/env python3
"""Save and restore the window layout of a Hyprland workspace.

    ws-snapshot.py save    [workspace]   # default: the active workspace
    ws-snapshot.py restore [workspace]

save    records, for every tiled window on the workspace, the command that started it
        (from /proc), the working directory of kitty terminals, and its position and size.
restore reopens the windows that are missing, one at a time and in layout order (so
        dwindle splits and the lua grid fill the same slots), then resizes every window
        to its saved size. Windows already on the workspace are reused, not reopened.

Only the window comes back, not what was inside it: a terminal reopens in its old
directory with a fresh shell, a browser opens a new window.
Snapshots live in ~/.local/state/hypr-snapshots/ws-<id>.json.
"""

import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path

STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "hypr-snapshots"
WAIT_PER_WINDOW = 10.0  # seconds to wait for a launched window to map


def hypr(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True).stdout


def hypr_json(what):
    return json.loads(hypr(what, "-j"))


def dispatch(lua):
    hypr("dispatch", lua)


def notify(msg):
    subprocess.run(["notify-send", "-a", "Hyprland", "Workspace snapshot", msg])


def lua_str(s):
    # Lua long string: no escaping needed as long as the closing bracket is unique
    level = "=" * 3
    while f"]{level}]" in s:
        level += "="
    return f"[{level}[{s}]{level}]"


def windows_on(ws):
    return [c for c in hypr_json("clients") if c["workspace"]["id"] == ws and c["mapped"]]


def layout_of(ws):
    for w in hypr_json("workspaces"):
        if w["id"] == ws:
            return w.get("tiledLayout", "")
    return ""


def layout_order(windows, layout):
    # The lua grid fills cells row by row; dwindle splits the newest window, so
    # opening left-to-right, then top-to-bottom, rebuilds the same tree.
    if layout == "lua:grid":
        return sorted(windows, key=lambda c: (c["at"][1], c["at"][0]))
    return sorted(windows, key=lambda c: (c["at"][0], c["at"][1]))


def command_of(client):
    pid = client["pid"]
    if client["class"] == "kitty":
        # the shell is kitty's child; its cwd is where the terminal was
        # (kitty also runs helper kittens; pick the process that is not one)
        cwd = str(Path.home())
        for task in Path(f"/proc/{pid}/task").iterdir():
            for kid in (task / "children").read_text().split():
                if Path(f"/proc/{kid}/comm").read_text().strip() != "kitten":
                    cwd = os.readlink(f"/proc/{kid}/cwd")
        return ["kitty", "--directory", cwd]
    argv = [a.decode() for a in Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0") if a]
    # Chromium rewrites its argv as one space-joined string
    if len(argv) == 1 and " " in argv[0] and not Path(argv[0]).exists():
        argv = shlex.split(argv[0])
    return argv


def save(ws):
    windows = [c for c in windows_on(ws) if not c["floating"]]
    if not windows:
        notify(f"Workspace {ws} has no tiled windows to save")
        return
    layout = layout_of(ws)
    snap = {
        "workspace": ws,
        "layout": layout,
        "windows": [
            {"class": c["class"], "title": c["title"], "command": command_of(c),
             "at": c["at"], "size": c["size"]}
            for c in layout_order(windows, layout)
        ],
    }
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / f"ws-{ws}.json").write_text(json.dumps(snap, indent=2))
    notify(f"Workspace {ws} saved ({len(windows)} windows)")


def bring_here(ws, client):
    """Put a window on ws, tiled: config rules may have floated it or sent it elsewhere
    (the Claude app's rule floats it on workspace 9)."""
    addr = client["address"]
    if client["workspace"]["id"] != ws:
        dispatch(f'hl.dsp.window.move({{ workspace = "{ws}", window = "address:{addr}" }})')
    if client["floating"]:
        dispatch(f'hl.dsp.window.float({{ action = "unset", window = "address:{addr}" }})')
    time.sleep(0.2)


def wait_for_new(ws, cls, known):
    # look on every workspace: a window rule may have sent the window somewhere else
    deadline = time.time() + WAIT_PER_WINDOW
    while time.time() < deadline:
        for c in hypr_json("clients"):
            if c["class"] == cls and c["address"] not in known and c["mapped"]:
                bring_here(ws, c)
                return c["address"]
        time.sleep(0.2)
    return None


def restore(ws):
    path = STATE / f"ws-{ws}.json"
    if not path.exists():
        notify(f"No snapshot for workspace {ws} (Ctrl+Shift+S saves one)")
        return
    snap = json.loads(path.read_text())

    # dwindle picks the split side from the mouse position; force right/bottom while
    # restoring so the tree comes back in the saved order (old value put back below)
    force_split = json.loads(hypr("getoption", "dwindle.force_split", "-j"))["int"]
    hypr("eval", "hl.config({ dwindle = { force_split = 2 } })")
    try:
        _restore(ws, snap)
    finally:
        hypr("eval", f"hl.config({{ dwindle = {{ force_split = {force_split} }} }})")


def _restore(ws, snap):
    present = windows_on(ws)
    claimed = set()
    slots = []  # (saved window, address)

    for saved in snap["windows"]:
        reuse = next((c["address"] for c in present
                      if c["class"] == saved["class"] and c["address"] not in claimed), None)
        if reuse:
            claimed.add(reuse)
            slots.append((saved, reuse))
            continue

        known = {c["address"] for c in hypr_json("clients")}
        cmd = shlex.join(saved["command"])
        # workspace/tile rules override config rules that would float the window or
        # send it elsewhere (e.g. the Claude app normally floats on workspace 9)
        dispatch(f'hl.dsp.exec_cmd({lua_str(cmd)}, {{ workspace = "{ws}", float = false }})')
        addr = wait_for_new(ws, saved["class"], known)
        if addr is None:
            # single-instance apps (vesktop, claude-desktop...) just focus the window
            # they already have: bring that one over instead
            other = next((c for c in hypr_json("clients")
                          if c["class"] == saved["class"] and c["workspace"]["id"] != ws
                          and c["address"] not in claimed), None)
            if other:
                addr = other["address"]
                bring_here(ws, other)
        if addr:
            claimed.add(addr)
            slots.append((saved, addr))

    # Splits come back 50/50: resize each window to its saved size. Two passes,
    # since resizing one window moves the splits its neighbours share.
    if snap.get("layout") != "lua:grid":
        for _ in range(2):
            for saved, addr in slots:
                w, h = saved["size"]
                dispatch(f'hl.dsp.window.resize({{ x = {w}, y = {h}, window = "address:{addr}" }})')
                time.sleep(0.05)

    missing = len(snap["windows"]) - len(slots)
    msg = f"Workspace {ws} restored"
    if missing:
        msg += f" ({missing} window(s) did not open)"
    notify(msg)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("save", "restore"):
        sys.exit(__doc__)
    ws = int(sys.argv[2]) if len(sys.argv) > 2 else hypr_json("activeworkspace")["id"]
    (save if sys.argv[1] == "save" else restore)(ws)


if __name__ == "__main__":
    main()
