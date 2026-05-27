#!/bin/bash
if ping -c 3 -W 2 -q google.com 2>/dev/null | grep -q "0% packet loss"; then
    echo '{"text": "󰛳", "class": "ok"}'
else
    echo '{"text": "󰪎", "class": "dead"}'
fi
