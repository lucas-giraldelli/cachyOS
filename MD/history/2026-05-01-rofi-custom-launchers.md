# 2026-05-01 — Rofi: Custom App Launchers via .desktop Files

## Summary

Pattern for adding custom tools/scripts to the rofi launcher (Alt+Space) as if they were native apps. Tested with rofi-calc; applies to anything: currency rates, charts, system tools, etc.

---

## Pattern

### 1. Create a script in `shell/.local/bin/`

```sh
#!/bin/sh
exec rofi -show calc -no-show-match -no-sort -calc-command "qalc {expression}"
```

- Stow target: `~/.local/bin/<script-name>`
- Must be `chmod +x`
- Use `exec` so the script doesn't leave a shell process behind

### 2. Create a `.desktop` entry in `applications/.local/share/applications/`

```ini
[Desktop Entry]
Name=Calculator
Comment=rofi-calc
Exec=rofi-calc-open
Icon=accessories-calculator
Type=Application
Categories=Utility;Calculator;
Keywords=calc;calculator;math;
```

- `Name` is what appears in rofi when searching
- `Keywords` adds aliases (e.g. searching "math" also finds it)
- `Exec` points to the script from step 1 — avoid `sh -c '...'` in Exec, it breaks rofi drun launch
- Icons: use standard freedesktop icon names or absolute paths

### 3. Stow caveats

`.desktop` files under `~/.local/share/applications/` are often real files (not symlinks) if created by apps. `stow -R` will conflict. Fix: copy manually.

```sh
cp applications/.local/share/applications/foo.desktop ~/.local/share/applications/
```

For scripts in `~/.local/bin/`, stow works normally but requires explicit `--target`:

```sh
stow --target=$HOME shell
```

---

## Ideas for future launchers

| Name | Script | What it does |
|------|--------|--------------|
| `btc` / `usd` | curl + wttr-like API | Current BTC/USD rate inline |
| `weather` | `curl wttr.in/?format=1` | One-line weather in rofi |
| `emoji` | `rofi -show emoji` + rofimoji | Emoji picker |
| `pass` | `rofi-pass` | Password manager integration |
| `clip` | already done via cliphist | Clipboard history |
