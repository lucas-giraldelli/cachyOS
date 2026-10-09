# Deadlock

**Steam AppID**: 1422450  
**Proton**: runs the Windows build (`game/citadel/bin/win64`)

## Keybinds (left-handed, IJKL)

Mouse in the left hand (Razer Naga Left-Handed), keyboard in the right (Avalanche split), so
movement is on **IJKL** instead of WASD.

### Where the binds live

| File | What |
|------|------|
| `~/.local/share/Steam/userdata/187603478/1422450/remote/cfg/citadelkeys_personal.lst` | **The real keybinds** (Settings → Hotkeys). Synced by Steam Cloud. |
| `.../1422450/local/cfg/user_keys_0_slot0.vcfg` | Only raw console binds (`F7 toggleconsole`). Not the hotkeys menu. |
| `game/citadel/pak01_083.vpk` | Default bind table (`"Templates" → "DEFAULT"`) and the action names. |

Edit `citadelkeys_personal.lst` only with the game closed, and back it up first.

### Current layout

| Action | Key |
|--------|-----|
| Move | I J K L |
| Abilities 1–4 | 7 8 9 0 |
| Ability upgrade | CTRL + 7–0 |
| Items 1–4 | A S Q W |
| Melee / Interact | U |
| Reload | O |
| Held item | ; |
| Hero sheet | ' |
| Quickbuy | N |
| Scoreboard (also used to read abilities) | 6 |
| Roll / Mantle / Crouch | SHIFT / SPACE / CTRL |
| Move up (flying heroes) | Y |
| Push to talk | T |
| Extra info | unbound — it shared CTRL with crouch; scoreboard covers it |

**Known issue**: abilities on 7–0 share fingers with movement (8 sits over I, the forward
key). Candidate fix: abilities on H O P ;, reload on M, held item on ', hero sheet on [.

### Rules

- **Never bind anything to ALT.** Hyprland uses ALT for window management. The game mode submap
  (see [gaming-personal.md](../gaming-personal.md#alt-binds--game-mode-submap)) passes ALT combos
  to the game, but ALT+[0-9] still switches workspaces.
- Ability action names for console binds: `+in_ability1..4`, `+in_item1..4`, `+in_mantle`
  (not `+jump`), `+in_innate1` (roll).
