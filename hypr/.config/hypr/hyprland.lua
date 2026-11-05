-- Hyprland config. Lua replaced hyprland.conf: Hyprland 0.57 dropped .conf support.
-- Wiki: https://wiki.hypr.land/configuring/
-- API reference for the installed version: /usr/share/hypr/stubs/hl.meta.lua
-- Validate before restarting: Hyprland --verify-config --config ~/.config/hypr/hyprland.lua
--
-- With a Lua config, `hyprctl dispatch` takes Lua and `hyprctl keyword` no longer works:
--   hyprctl dispatch 'hl.dsp.submap("game")'
--   hyprctl eval 'hl.unbind("ALT + mouse:272")'


------------------
---- MONITORS ----
------------------

hl.monitor({ output = "DP-2", mode = "2560x1440@360", position = "0x0", scale = 1 })
-- Headless fallback: keeps Hyprland alive if DP-2 glitches or disconnects
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "nemo"
local menu        = "walker"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("powerprofilesctl set performance")
    -- hl.exec_cmd("fcitx5 --daemon")
    -- waybar is off while smart-shell replaces it (re-enable: uncomment, then
    -- `systemctl --user enable waybar.service`)
    -- hl.exec_cmd("systemctl --user start waybar.service")
    hl.exec_cmd("qs -p ~/projects/smart-shell/shell -n")
    -- hl.exec_cmd("mako") -- replaced by smart-shell's notification popups
    -- Static wallpaper
    -- hl.exec_cmd("awww-daemon && awww img ~/Pictures/pkmn.png")
    -- Live wallpaper
    hl.exec_cmd('mpvpaper -p -a FULL -o "loop" DP-2 /home/lukesh/wallpapers/live.mp4')

    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("systemctl --user start elephant.service walker.service")
    hl.exec_cmd("~/.config/waybar/scripts/whatsapp-volume.sh")
    hl.exec_cmd("~/.config/hypr/scripts/game-submap.sh")
    -- The XWayland socket symlink is handled by the xwayland-socket-symlink.service
    -- user unit (self-healing across Steam/XWayland restarts, not just boot).
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Tokyonight-Dark")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "kvantum")


-----------------------
----- PERMISSIONS -----
-----------------------

-- Permission changes require a Hyprland restart; they are not applied on the fly.
-- hl.config({ ecosystem = { enforce_permissions = true } })

hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/wf-recorder", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in = 5,
        -- The bottom gap matches the smart-shell dock's edge gap (Theme.edge 8 +
        -- border_size 2), so the dock sits evenly between window and screen
        gaps_out = { top = 20, right = 20, bottom = 10, left = 20 },

        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- See https://wiki.hypr.land/configuring/extra/tearing/ before turning this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        -- Transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        blur = {
            enabled  = true,
            size     = 6,
            passes   = 3,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,    -- 0 or 1 disables the anime mascot wallpapers
        disable_hyprland_logo   = false, -- true disables the random logo / anime girl background
        vrr                     = 1,
        render_unfocused_fps    = 120,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout   = "us",
        kb_variant  = "intl",
        kb_model    = "",
        left_handed = false,
        kb_options  = "",
        kb_rules    = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 to 1.0, 0 means no modification

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

hl.device({
    name          = "razer-razer-naga-left-handed-edition",
    left_handed   = true,
    scroll_factor = 1.0,
    sensitivity   = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

local screenshot = "hyprshot -m region --clipboard-only --silent"
local recordToggle = "~/.config/hypr/scripts/record-toggle.sh"

-- ALT + [0-9] switches workspace, ALT + SHIFT + [0-9] moves the active window there.
-- Shared by the normal binds and the game submap.
local function bindWorkspaceKeys()
    for i = 1, 10 do
        local key = i % 10 -- workspace 10 is on key 0
        hl.bind("ALT + " .. key,         hl.dsp.focus({ workspace = i }))
        hl.bind("ALT + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
    end
end

local function bindMediaKeys()
    hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
end

local function bindVolumeKeys()
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"),      { locked = true, repeating = true })
    hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
end

hl.bind("Print",        hl.dsp.exec_cmd(screenshot))
hl.bind("CTRL + Print", hl.dsp.exec_cmd('grim -g "$(slurp)" /tmp/ocr-shot.png && tesseract /tmp/ocr-shot.png stdout -l por+eng | wl-copy'))
hl.bind("ALT + Print",  hl.dsp.exec_cmd(recordToggle))
hl.bind(mainMod .. " + V",   hl.dsp.exec_cmd("walker -m clipboard"))
-- Screen off on purpose: this starts the OLED panel-care cycle
hl.bind(mainMod .. " + F10", hl.dsp.dpms({ action = "toggle", monitor = "DP-2" }))

-- Changed SUPER to ALT: split keyboard, right-hand ALT is within reach
hl.bind("ALT + Q",         hl.dsp.window.close())
hl.bind("ALT + T",         hl.dsp.exec_cmd(terminal))
hl.bind("ALT + E",         hl.dsp.exec_cmd(fileManager))
hl.bind("ALT + R",         hl.dsp.submap("resize"))
hl.bind("ALT + SPACE",     hl.dsp.exec_cmd(menu))
hl.bind("ALT + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind("ALT + Z",         hl.dsp.workspace.toggle_special("magic"))
hl.bind("ALT + SHIFT + Z", hl.dsp.window.move({ workspace = "special:magic" }))

-- Log out of the session (uwsm-managed, so stop the unit rather than exiting
-- Hyprland directly). Also the recovery for a stale XWayland: restarting the
-- session is the only way to get a fresh X auth cookie.
hl.bind("ALT + SHIFT + Q", hl.dsp.exec_cmd("uwsm stop"))

-- Move focus with ALT + WASD
hl.bind("ALT + W", hl.dsp.focus({ direction = "up" }))
hl.bind("ALT + A", hl.dsp.focus({ direction = "left" }))
hl.bind("ALT + S", hl.dsp.focus({ direction = "down" }))
hl.bind("ALT + D", hl.dsp.focus({ direction = "right" }))

-- Swap windows with ALT + SHIFT + WASD
hl.bind("ALT + SHIFT + W", hl.dsp.window.swap({ direction = "up" }))
hl.bind("ALT + SHIFT + A", hl.dsp.window.swap({ direction = "left" }))
hl.bind("ALT + SHIFT + S", hl.dsp.window.swap({ direction = "down" }))
hl.bind("ALT + SHIFT + D", hl.dsp.window.swap({ direction = "right" }))

bindWorkspaceKeys()

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind("F7", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Move/resize windows with mainMod or ALT + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("ALT + mouse:272",         hl.dsp.window.drag(),   { mouse = true })
hl.bind("ALT + mouse:273",         hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys for volume and LCD brightness
bindVolumeKeys()
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                { locked = true, repeating = true })
hl.bind("CTRL + ALT + 1", hl.dsp.exec_cmd("~/.config/waybar/scripts/brightness-set.sh up"))
hl.bind("CTRL + ALT + 2", hl.dsp.exec_cmd("~/.config/waybar/scripts/brightness-set.sh down"))

-- Requires playerctl
bindMediaKeys()

-- Resize mode: ALT+R to enter, arrows to resize, ESC to exit
hl.define_submap("resize", function()
    hl.bind("right",  hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }), { repeating = true })
    hl.bind("left",   hl.dsp.window.resize({ x = -50, y = 0,   relative = true }), { repeating = true })
    hl.bind("up",     hl.dsp.window.resize({ x = 0,   y = -50, relative = true }), { repeating = true })
    hl.bind("down",   hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.exec_cmd("hyprctl dismissnotify 1"))
    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Game mode: entered automatically by scripts/game-submap.sh while a Steam game
-- (steam_app_*) has focus. Only these binds stay active (switch workspace, move
-- the game to one, screenshot and recording, media keys), so every other ALT
-- combo (ALT+Q close, ALT+WASD, ...) and F7 go to the game.
hl.define_submap("game", function()
    bindWorkspaceKeys()
    -- Screenshots and recording keep working over the game
    hl.bind("Print",       hl.dsp.exec_cmd(screenshot))
    hl.bind("ALT + Print", hl.dsp.exec_cmd(recordToggle))
    bindVolumeKeys()
    bindMediaKeys()
    -- Escape hatch if the watcher script dies while a game is focused
    hl.bind(mainMod .. " + escape", hl.dsp.submap("reset"))
end)


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Headless "SHOTS" output (screenshots taken by agents): it gets workspace 40, so creating it
-- never pulls one of the real workspaces onto an invisible screen.
hl.workspace_rule({ workspace = "40", monitor = "SHOTS", default = true })

-- smart-shell dock (~/projects/smart-shell): blur behind its glass. ignore_alpha
-- keeps the transparent parts of the surface (room for popovers, the pet...) sharp;
-- blur_popups gives its popovers (control center, calendar...) the same glass.
hl.layer_rule({
    name         = "smart-shell-blur",
    match        = { namespace = "smart-shell" },
    blur         = true,
    blur_popups  = true,
    ignore_alpha = 0.2,
})

-- walker: the same glass as the dock (its smart-shell theme)
hl.layer_rule({
    name         = "walker-blur",
    match        = { namespace = "walker" },
    blur         = true,
    blur_popups  = true,
    ignore_alpha = 0.2,
})

hl.window_rule({
    name      = "jira-float",
    match     = { class = "chrome-[^.]+\\.atlassian\\.net.*" },
    float     = true,
    size      = "1240 1368",
    move      = "20 20",
    workspace = "2",
})

hl.window_rule({
    name      = "github-float",
    match     = { class = "chrome-github\\.com__[^_]+_marketplace.*" },
    float     = true,
    size      = "1240 1368",
    move      = "1300 20",
    workspace = "2",
})

hl.window_rule({
    name  = "calendar-popup",
    match = { title = "Calendário" },
    float = true,
    size  = "300 230",
    move  = "2235 1088",
    pin   = true,
})

hl.window_rule({
    name  = "weather-popup",
    match = { title = "Clima" },
    float = true,
    size  = "320 330",
    move  = "2050 1055",
    pin   = true,
})

hl.window_rule({
    name  = "pavucontrol-float",
    match = { class = "org.pulseaudio.pavucontrol" },
    float = true,
    size  = "600 400",
    move  = "1940 998",
    pin   = true,
})

hl.window_rule({
    name   = "btop-float",
    match  = { class = "btop-float" },
    float  = true,
    size   = "1400 800",
    center = true,
})

hl.window_rule({
    name   = "lazydocker-float",
    match  = { title = "lazydocker" },
    float  = true,
    size   = "1400 800",
    center = true,
})

hl.window_rule({
    name  = "qbittorrent-float",
    match = { class = "qbittorrent" },
    float = true,
})

hl.window_rule({
    -- Blender opens large and takes over the active screen; workspace 9 is its bench.
    name      = "blender-workspace",
    match     = { class = "^([Bb]lender.*)$" },
    workspace = "9 silent",
})

hl.window_rule({
    -- Mario Tennis 64 recomp: test runs (SDL_APP_ID=MT64Test) go to workspace 5.
    -- The game opened normally (class MT64Recompiled) opens on the current workspace.
    name      = "mt64recomp-workspace",
    match     = { class = "^(MT64Test)$" },
    workspace = "5 silent",
    -- Vulkan swapchain acquire blocks forever when the workspace is hidden; keep presenting.
    render_unfocused = true,
})
hl.window_rule({
    match            = { class = "^(MT64Test|MT64Recompiled)$" },
    render_unfocused = true,
})

hl.window_rule({
    -- PortShelf in dev mode (title "PortShelf (dev)"): always on 5. The installed one opens in place.
    name             = "portshelf-workspace",
    match            = { title = "^(PortShelf \\(dev\\))$" },
    workspace        = "5 silent",
    render_unfocused = true,
})

hl.window_rule({
    -- Playwright's Chromium: the agent's bench, away from the work screens.
    name      = "playwright-chromium",
    match     = { class = "^([Cc]hromium.*)$" },
    workspace = "4 silent",
})

hl.window_rule({
    -- Ignore maximize requests from all apps
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name   = "nemo-float",
    match  = { class = "nemo" },
    float  = true,
    size   = "1170 703",
    center = true,
})

hl.window_rule({
    name      = "steam-workspace",
    match     = { class = "steam" },
    workspace = "5",
})

hl.window_rule({
    name   = "steam-friends-float",
    match  = { class = "steam", initial_title = "Friends List" },
    float  = true,
    size   = "380 700",
    center = true,
})

hl.window_rule({
    name   = "steam-settings-float",
    match  = { class = "steam", initial_title = "Steam Settings" },
    float  = true,
    size   = "940 640",
    center = true,
})

hl.window_rule({
    name   = "steam-dialogs-float",
    match  = { class = "steam", initial_title = "negative:^Steam$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name      = "thunderbird-workspace",
    match     = { class = "org.mozilla.Thunderbird" },
    workspace = "8",
})

hl.window_rule({
    name  = "thunderbird-reminder-float",
    match = { class = "org.mozilla.Thunderbird", title = "^$" },
    float = true,
    pin   = true,
    size  = "500 300",
    move  = "100%-520 50",
})

hl.window_rule({
    name   = "openvpn-float",
    match  = { class = "OpenVPN-Connect" },
    float  = true,
    size   = "400 685",
    center = true,
})

hl.window_rule({
    name      = "vesktop-float",
    match     = { class = "vesktop" },
    float     = true,
    size      = "1280 800",
    center    = true,
    workspace = "5",
})

hl.window_rule({
    name      = "slack-workspace",
    match     = { class = "slack" },
    workspace = "2",
})

hl.window_rule({
    name      = "dbeaver-workspace",
    match     = { class = "DBeaver" },
    workspace = "6",
})

hl.window_rule({
    name      = "youtube-music-workspace",
    match     = { class = "chrome-music.youtube.com.*" },
    workspace = "7",
})

hl.window_rule({
    name      = "whatsapp-workspace",
    match     = { class = "chrome-web.whatsapp.com.*" },
    workspace = "7",
})

hl.window_rule({
    name      = "qbit-web-workspace",
    match     = { class = "chrome-localhost__.*" },
    workspace = "10",
})

hl.window_rule({
    name      = "vscode-workspace",
    match     = { class = "Code" },
    workspace = "3",
})

hl.window_rule({
    name      = "tns-desktop",
    match     = { class = "tns-desktop" },
    float     = true,
    size      = "1512 1340",
    move      = "20 40",
    workspace = "4",
})

hl.window_rule({
    name      = "smite2",
    match     = { class = "steam_app_2437170" },
    immediate = true,
})

hl.window_rule({
    name             = "farever",
    match            = { class = "steam_app_3672400" },
    immediate        = true,
    render_unfocused = true,
})

hl.window_rule({
    name      = "tns-mobile",
    match     = { class = "tns-mobile" },
    float     = true,
    size      = "500 900",
    move      = "1572 40",
    workspace = "4",
})

hl.window_rule({
    name   = "vlc-float",
    match  = { class = "vlc" },
    float  = true,
    size   = "1280 720",
    center = true,
})

hl.window_rule({
    -- Claude desktop app: keep it floating so it stays a movable overlay
    -- on any workspace instead of tiling into the layout.
    name      = "claude-float",
    match     = { class = "com.anthropic.Claude" },
    float     = true,
    size      = "1920 1200",
    center    = true,
    workspace = "9",
})

hl.window_rule({
    name      = "snowbrawl",
    match     = { class = "^(snowbrawl|sno2play)\\.exe$" },
    float     = true,
    size      = "640 480",
    center    = true,
    workspace = "6",
})

hl.window_rule({
    name   = "browser-file-picker",
    match  = { title = "^(File Upload|Open Files?|Save (?:File|As|Copy)|Open Folder|Choose Files?)" },
    float  = true,
    size   = "1000 650",
    center = true,
})

hl.window_rule({
    name      = "unity-editor",
    match     = { class = "^([Uu]nity.*|[Uu]nityhub.*)$" },
    workspace = "5 silent",
})

hl.window_rule({
    name      = "blender-ws20",
    match     = { class = "^blender$" },
    workspace = "20 silent",
})

hl.window_rule({
    name      = "unity-ws19",
    match     = { class = "^(Unity|Unityhub-unity-editor.*)$" },
    workspace = "19 silent",
})

hl.window_rule({
    name      = "godot-ws19",
    match     = { class = "^(Godot)$" },
    workspace = "19 silent",
})

-- Kite Adrift (game window): lives on workspace 19 and keeps rendering while
-- hidden, so recordings run at full speed
hl.window_rule({
    match            = { class = "^(Kite Adrift)$" },
    workspace        = "19 silent",
    render_unfocused = true,
    float            = true,
    size             = "720 1280",
})
