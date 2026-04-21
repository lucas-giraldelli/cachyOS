#!/bin/bash

YEAR=$(date +%Y)
MONTH=$(date +%m)
FILE="/var/lib/power-tracker/$YEAR-$MONTH.json"
TARIFA="0.85213"

if [ ! -f "$FILE" ]; then
    echo '{"text": "⚡ R$ --", "tooltip": "Sem dados ainda"}'
    exit 0
fi

python3 -c "
import json
with open('$FILE') as f:
    d = json.load(f)
kwh = d['kwh']
reais = kwh * $TARIFA
out = {'text': f'⚡ R\$ {reais:.2f}', 'tooltip': f'CPU+RAM: {kwh:.2f} kWh x R\$ $TARIFA/kWh (aprox. 50-60% do total)'}
print(json.dumps(out))
"
