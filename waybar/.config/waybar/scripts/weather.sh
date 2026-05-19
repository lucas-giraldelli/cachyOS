#!/bin/bash

WEATHER=$(curl -sf --max-time 5 "wttr.in/?format=%C|%t|%h|%w" 2>/dev/null)

if [[ -z "$WEATHER" ]]; then
    echo '{"text": "  --°C", "class": "error", "tooltip": "Weather unavailable"}'
    exit 0
fi

CONDITION=$(echo "$WEATHER" | cut -d'|' -f1 | tr '[:upper:]' '[:lower:]' | xargs)
TEMP_STR=$(echo "$WEATHER" | cut -d'|' -f2 | xargs)
HUMIDITY=$(echo "$WEATHER" | cut -d'|' -f3 | xargs)
WIND=$(echo "$WEATHER" | cut -d'|' -f4 | xargs)
TEMP=$(echo "$TEMP_STR" | grep -oP '[+-]?\d+' | head -1)

HOUR=$(date +%H | sed 's/^0//')
(( HOUR >= 6 && HOUR < 20 )) && IS_DAY=true || IS_DAY=false

if [[ "$CONDITION" == *thunder* || "$CONDITION" == *storm* ]]; then
    ICON="⛈"; CLASS="storm"
elif [[ "$CONDITION" == *blizzard* || "$CONDITION" == *"heavy snow"* || "$CONDITION" == *"moderate snow"* ]]; then
    ICON="❄"; CLASS="snow"
elif [[ "$CONDITION" == *snow* || "$CONDITION" == *sleet* || "$CONDITION" == *ice* ]]; then
    ICON="🌨"; CLASS="snow"
elif [[ "$CONDITION" == *fog* || "$CONDITION" == *mist* || "$CONDITION" == *haze* ]]; then
    ICON="🌫"; CLASS="fog"
elif [[ "$CONDITION" == *"heavy rain"* || "$CONDITION" == *torrential* || "$CONDITION" == *"moderate rain"* ]]; then
    ICON="🌧"; CLASS="rain"
elif [[ "$CONDITION" == *drizzle* || "$CONDITION" == *"light rain"* || "$CONDITION" == *"patchy rain"* || "$CONDITION" == *shower* ]]; then
    $IS_DAY && ICON="🌦" || ICON="🌧🌙"; CLASS="rain"
elif [[ "$CONDITION" == *overcast* ]]; then
    ICON="☁"; CLASS="cloudy"
elif [[ "$CONDITION" == *"partly cloudy"* || "$CONDITION" == *partly* ]]; then
    if $IS_DAY; then
        (( TEMP < 15 )) && ICON="🌥❄" || ICON="⛅"
    else
        ICON="☁🌙"
    fi
    CLASS="cloudy"
elif [[ "$CONDITION" == *cloudy* ]]; then
    $IS_DAY && ICON="⛅" || ICON="☁🌙"; CLASS="cloudy"
elif [[ "$CONDITION" == *sunny* || "$CONDITION" == *clear* ]]; then
    if $IS_DAY; then
        (( TEMP < 15 )) && ICON="🌤❄" || ICON="☀"
    else
        (( TEMP < 10 )) && ICON="🌙❄" || ICON="🌙"
    fi
    CLASS="clear"
else
    $IS_DAY && ICON="☀" || ICON="🌙"; CLASS="ok"
fi

TOOLTIP="$CONDITION\n$TEMP_STR  |  Humidity: $HUMIDITY  |  Wind: $WIND"

echo "{\"text\": \"$ICON  $TEMP_STR\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"
