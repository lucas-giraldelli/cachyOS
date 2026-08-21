source /usr/share/cachyos-fish-config/cachyos-config.fish

set -x GTK_IM_MODULE fcitx
set -x QT_IM_MODULE fcitx
set -x XMODIFIERS @im=fcitx

function cachy
    cd ~/projects/cachyOS && agy --dangerously-skip-permissions
end

function pclaude
    set -x CLAUDE_CONFIG_DIR ~/.claude-personal
    claude $argv
end

function browser-stack
    BrowserStackLocal --key $argv[1] --force-local
end

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end


# Added by Antigravity CLI installer
set -gx PATH "/home/lukesh/.local/bin" $PATH
