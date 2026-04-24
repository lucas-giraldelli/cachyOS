# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## System Overview

### OS & Kernel
- **CachyOS Linux** (rolling release, Arch-based)
- Kernel: `6.19.12-1-cachyos`
- AUR helper: `paru v2.1.0` — use `paru` instead of `pacman` for installs

### Hardware
| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 7 5800X3D (8c/16t) |
| RAM | 48 GB |
| GPU | NVIDIA RTX 4080 16GB — driver `595.58.03` |
| Storage | NVMe Samsung 980 1TB (root+home), Kingston SSD 480GB, WD HDD 2TB |
| Monitor | Samsung Odyssey G60SD — 2560x1440 @ 360Hz via DP-2 |
| Mouse | Razer Naga Left-Handed Edition + vitvlkv Avalanche |

### Desktop Environment
- **Window Manager**: Hyprland `0.54.3` on **Wayland**
- Bar: `waybar`
- Launcher: `rofi`, `wofi`
- Notifications: `dunst`
- Terminals: `kitty` (primary), `alacritty`
- Browsers: `zen-browser`, `chromium`
- Media: `vlc`
- Gaming: `steam`

### Applications
| App | Type | Details |
|-----|------|---------|
| WhatsApp | Chromium PWA | `--class=whatsapp`, `--app=https://web.whatsapp.com`, profile: `~/.config/chromium-personal`, extension: `~/.config/chromium-wa-ext`, desktop: `~/.local/share/applications/whatsapp.desktop`, pinned to workspace 7 |

### Wayland Rules
- **NEVER suggest `xinput`** — it doesn't work on Wayland/Hyprland
- Mouse/input config lives in `~/.config/hypr/hyprland.conf` under the `input {}` block
- Current mouse sensitivity: `-0.5` (range: -1.0 to 1.0)
- To change mouse speed: edit `sensitivity` in `~/.config/hypr/hyprland.conf`, then `hyprctl reload`
- Per-device config: use `device { name=...; sensitivity=... }` in hyprland.conf

### Package Management
- Use `paru` for everything (wraps pacman + AUR)
- `paru -S <pkg>` to install, `paru -Rns <pkg>` to remove with deps
- Before suggesting a package install, check if it's already installed: `paru -Q <pkg>`
- Before suggesting a tool, check if it works on Wayland/Hyprland

## Build & Test

_Add your build and test commands here_

## Conventions & Patterns

- Always verify tools work on **Wayland** before suggesting them
- Always check with `paru -Q` before suggesting installs
- Config files for Hyprland: `~/.config/hypr/`

## Language

- **All files in this repo must be written in English** — docs, comments, commit messages, scripts
- Conversation with the user can be in Portuguese (pt-BR), but nothing goes into the repo in Portuguese
