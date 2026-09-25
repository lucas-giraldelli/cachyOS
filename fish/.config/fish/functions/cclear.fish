function cclear --description 'Open a clean fish shell started by systemd instead of Hyprland'
    # Programs started from Hyprland inherit its open files; when those pile up (a leak in
    # a client), tools that walk every open file (makepkg's fakeroot, for example) crawl.
    # A shell started by the systemd user manager begins with none of them.
    systemd-run --user --pty --same-dir --wait --collect --quiet fish $argv
end
