# 2026-04-27 — Waybar: BT Battery Widget + Performance Group

## What was added

Two improvements to the waybar config:

1. **Bluetooth battery widget** — shows battery % for any connected BT device that exposes the Serial Port Profile (SPP/RFCOMM)
2. **Performance group** — CPU, RAM and GPU grouped into a single fixed-width container

---

## Bluetooth battery widget

### Problem

The Kuba Mali 2 TWS (and devices like it) do not expose `org.bluez.Battery1` via D-Bus, so the built-in waybar `bluetooth` module and tools like `gobbl` return nothing. BlueZ never creates the Battery1 object for these devices because they advertise HFP in the HF unit role (`0x111E`) rather than as an Audio Gateway (`0x111F`), and their firmware doesn't respond to the standard BlueZ battery negotiation.

Windows and Android read battery via proprietary paths or quirk tables — not via the standard BlueZ Battery1 interface.

### Solution

The `bluetooth-battery` AUR package (`python-bluetooth-battery`) reads battery level by connecting via RFCOMM to the device's Serial Port channel and listening for AT command responses (`AT+CIND`, `AT+IPHONEACCEV`). This works on any device with UUID `00001101` (Serial Port Profile), which includes most modern TWS headsets.

```bash
paru -S python-bluetooth-battery
```

Test:
```bash
bluetooth_battery <MAC>
# Battery level for XX:XX:XX:XX:XX:XX is 90%
```

### Script

`~/.config/waybar/scripts/bt-battery.sh` — iterates `bluetoothctl devices Connected`, runs `bluetooth_battery` on each, and returns JSON for waybar. Hidden when no device reports battery.

### Waybar module

```jsonc
"custom/bt-battery": {
    "exec": "~/.config/waybar/scripts/bt-battery.sh",
    "return-type": "json",
    "interval": 60
}
```

Position in `modules-right`: between `tray` and `custom/docker`.

---

## Performance group

CPU, memory and GPU were previously three separate modules with independent backgrounds and widths. Grouped using the native waybar `group` module:

```jsonc
"group/perf": {
    "orientation": "horizontal",
    "modules": ["cpu", "memory", "custom/gpu"]
}
```

CSS: the group container gets `border-radius: 8px` and solid background; inner modules get `background-color: transparent` and `min-width: 72px` to prevent the container from resizing as values change between 1–3 digits.

```css
#perf {
    border-radius: 8px;
    padding: 0;
}

#perf #cpu,
#perf #memory,
#perf #custom-gpu {
    background-color: transparent;
    padding: 4px 10px;
    min-width: 72px;
}
```

Note: `font-variant-numeric: tabular-nums` is not valid in GTK CSS — waybar crashes on startup if included.
