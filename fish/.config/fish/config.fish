source /usr/share/cachyos-fish-config/cachyos-config.fish

set -x GTK_IM_MODULE fcitx
set -x QT_IM_MODULE fcitx
set -x XMODIFIERS @im=fcitx

function cachy
    cd ~/projects/cachyOS && pclaude --dangerously-skip-permissions
end

function pclaude
    set -x CLAUDE_CONFIG_DIR ~/.claude-personal
    claude $argv
end

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
