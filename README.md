# cachyOS

Personal configuration for a CachyOS desktop running Hyprland on Wayland. The repository holds dotfiles, user services, a few system level files, a Docker Compose media stack, and notes on problems that were diagnosed and fixed on this machine.

## System

| Component | Details |
|-----------|---------|
| Distribution | CachyOS (Arch based, rolling release) |
| Compositor | Hyprland on Wayland |
| Bar | Waybar |
| Launchers | Rofi, Wofi |
| Notifications | Dunst |
| Terminals | Kitty, Alacritty |
| Shell | Fish (Zsh configuration is also kept) |
| CPU | AMD Ryzen 7 5800X3D |
| GPU | NVIDIA RTX 4080 |
| Monitor | 2560x1440 at 360 Hz |

## Layout

Each top level directory is a [GNU Stow](https://www.gnu.org/software/stow/) package that mirrors the home directory. For example, `hypr/.config/hypr/hyprland.conf` is linked to `~/.config/hypr/hyprland.conf`.

| Package | Contents |
|---------|----------|
| `applications` | Desktop entries for Chromium web apps and custom launchers |
| `btop` | btop configuration |
| `chromium-ext` | Unpacked Chromium extension loaded by the Jira web app profile |
| `chromium-wa-ext` | Unpacked Chromium extension loaded by the WhatsApp web app profile |
| `dunst`, `mako` | Notification daemon configuration |
| `environment` | Session environment variables (`environment.d`) for input methods and gaming |
| `fish` | Fish configuration and functions |
| `gtk`, `qt`, `nwg-look` | GTK, Qt and Kvantum theming |
| `hypr` | Hyprland configuration, window rules and helper scripts |
| `kitty` | Kitty terminal configuration |
| `rofi` | Rofi configuration |
| `scripts` | Standalone scripts, linked to `~/scripts` |
| `shell` | Zsh configuration, Git configuration and XCompose rules |
| `systemd` | User services and timers |
| `waybar` | Waybar configuration, styles and custom modules |
| `wireplumber` | Audio policy overrides |

The following directories are not Stow packages:

| Directory | Purpose |
|-----------|---------|
| `system` | Files installed as root under `/etc` and `/usr/local/bin`, such as pacman hooks, tmpfiles rules and systemd units. They are copied into place manually. |
| `media-stack` | Docker Compose definition for the self hosted media stack. See `media-stack/Media-Stack/README.md`. |
| `MD` | Documentation, troubleshooting guides and a dated history of fixes in `MD/history`. |

## Installation

Install Stow and link the packages you need from the repository root:

```bash
paru -S stow
cd ~/projects/cachyOS
stow -t ~ hypr waybar kitty fish rofi dunst systemd
```

System files under `system` must be copied with root privileges, for example:

```bash
sudo install -Dm644 system/etc/tmpfiles.d/x11.conf /etc/tmpfiles.d/x11.conf
```

After linking user units, reload systemd and enable the timers that are required:

```bash
systemctl --user daemon-reload
systemctl --user enable --now arr-stall-requeue.timer
```

## Secrets

Credentials are never committed. Files named `.env` are ignored by Git, and each component that needs secrets reads them from a local `.env` file:

| File | Used by | Template |
|------|---------|----------|
| `scripts/scripts/.env` | `arr-stall-requeue.service` | `scripts/scripts/.env.example` |
| `media-stack/Media-Stack/.env` | Docker Compose (VPN and tunnel credentials) | Variables referenced in `docker-compose.yml` |

Restrict the permissions of these files with `chmod 600`.

## Notes

The `MD` directory documents recurring issues and their solutions, including Hyprland crashes, the Waybar system tray, NTFS mounts, PAM lockouts and the media stack. Entries in `MD/history` record the symptoms, the root cause and the fix for each incident.
