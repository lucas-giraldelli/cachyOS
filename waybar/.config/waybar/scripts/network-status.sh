#!/bin/bash
if ping -c 1 -W 2 -q google.com &>/dev/null; then
    echo '{"text": "󰛳", "class": "ok"}'
else
    echo '{"text": "󰪎", "class": "dead"}'
fi
