#!/bin/bash
# Re-registers Electron apps that lose their SNI tray icon when waybar restarts.
# Waits for waybar to register the StatusNotifierWatcher before restarting apps.

sleep 3

if pgrep -x slack > /dev/null; then
    pkill -x slack
    sleep 1
    slack &
fi

if pgrep -x vesktop > /dev/null; then
    pkill -x vesktop
    sleep 1
    vesktop &
fi
