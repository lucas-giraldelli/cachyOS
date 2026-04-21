#!/bin/bash

icon="󰡨"

if ! systemctl is-active --quiet docker; then
    echo "{\"text\": \"$icon\", \"class\": \"dead\", \"tooltip\": \"Docker stopped\"}"
    exit 0
fi

bad=$(docker ps -a --format '{{.Status}}' 2>/dev/null | grep -cE '^(Paused|Restarting|Exited \([^0]\))')

if [ "$bad" -gt 0 ]; then
    echo "{\"text\": \"$icon\", \"class\": \"warn\", \"tooltip\": \"$bad container(s) with issues\"}"
else
    echo "{\"text\": \"$icon\", \"class\": \"ok\", \"tooltip\": \"Docker running\"}"
fi
