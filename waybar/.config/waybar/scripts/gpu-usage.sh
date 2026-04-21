#!/bin/bash
usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
mem_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
mem_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')

if [ -z "$usage" ]; then
    echo '{"text": "󰾲  N/A", "class": "dead"}'
else
    echo "{\"text\": \"󰾲  ${usage}%\", \"tooltip\": \"GPU: ${usage}%\\nVRAM: ${mem_used}MB / ${mem_total}MB\", \"class\": \"ok\"}"
fi
