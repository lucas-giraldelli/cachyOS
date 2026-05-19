#!/bin/bash

WEATHER=$(curl -sf --max-time 5 "wttr.in/?format=%C|%t|%h|%w" 2>/dev/null)

if [[ -z "$WEATHER" ]]; then
    echo '{"text": "󰖑  --°C", "class": "error", "tooltip": "Weather unavailable"}'
    exit 0
fi

CONDITION=$(echo "$WEATHER" | cut -d'|' -f1 | tr '[:upper:]' '[:lower:]' | xargs)
TEMP_STR=$(echo "$WEATHER" | cut -d'|' -f2 | xargs)
HUMIDITY=$(echo "$WEATHER" | cut -d'|' -f3 | xargs)
WIND=$(echo "$WEATHER" | cut -d'|' -f4 | xargs)
TEMP=$(echo "$TEMP_STR" | grep -oP '[+-]?\d+' | head -1)

HOUR=$(date +%H | sed 's/^0//')
(( HOUR >= 6 && HOUR < 20 )) && IS_DAY=true || IS_DAY=false

# Nerd Font MD weather icons
ICO_SUNNY="󰖜"        # nf-md-weather_sunny
ICO_NIGHT="󰖕"        # nf-md-weather_night
ICO_PARTLY="󰖖"       # nf-md-weather_partly_cloudy
ICO_CLOUDY="󰖐"       # nf-md-weather_cloudy
ICO_RAIN="󰖘"         # nf-md-weather_rainy
ICO_POURING="󰖗"      # nf-md-weather_pouring
ICO_THUNDER="󰖔"      # nf-md-weather_lightning_rainy
ICO_SNOW="󰖙"         # nf-md-weather_snowy
ICO_SNOW_H="󰖚"       # nf-md-weather_snowy_heavy
ICO_FOG="󰖑"          # nf-md-weather_fog
ICO_COLD="󰹶"         # nf-md-snowflake (cold modifier)

if [[ "$CONDITION" == *thunder* || "$CONDITION" == *storm* ]]; then
    ICON="$ICO_THUNDER"; CLASS="storm"
elif [[ "$CONDITION" == *blizzard* || "$CONDITION" == *"heavy snow"* || "$CONDITION" == *"moderate snow"* ]]; then
    ICON="$ICO_SNOW_H"; CLASS="snow"
elif [[ "$CONDITION" == *snow* || "$CONDITION" == *sleet* || "$CONDITION" == *ice* ]]; then
    ICON="$ICO_SNOW"; CLASS="snow"
elif [[ "$CONDITION" == *fog* || "$CONDITION" == *mist* || "$CONDITION" == *haze* ]]; then
    ICON="$ICO_FOG"; CLASS="fog"
elif [[ "$CONDITION" == *"heavy rain"* || "$CONDITION" == *torrential* || "$CONDITION" == *"moderate rain"* ]]; then
    ICON="$ICO_POURING"; CLASS="rain"
elif [[ "$CONDITION" == *drizzle* || "$CONDITION" == *"light rain"* || "$CONDITION" == *"patchy rain"* || "$CONDITION" == *shower* ]]; then
    $IS_DAY && ICON="$ICO_RAIN" || ICON="$ICO_NIGHT$ICO_RAIN"; CLASS="rain"
elif [[ "$CONDITION" == *overcast* ]]; then
    ICON="$ICO_CLOUDY"; CLASS="cloudy"
elif [[ "$CONDITION" == *"partly cloudy"* || "$CONDITION" == *partly* ]]; then
    if $IS_DAY; then
        (( TEMP < 15 )) && ICON="$ICO_PARTLY$ICO_COLD" || ICON="$ICO_PARTLY"
    else
        ICON="$ICO_NIGHT$ICO_CLOUDY"
    fi
    CLASS="cloudy"
elif [[ "$CONDITION" == *cloudy* ]]; then
    $IS_DAY && ICON="$ICO_CLOUDY" || ICON="$ICO_NIGHT$ICO_CLOUDY"; CLASS="cloudy"
elif [[ "$CONDITION" == *sunny* || "$CONDITION" == *clear* ]]; then
    if $IS_DAY; then
        (( TEMP < 15 )) && ICON="$ICO_SUNNY$ICO_COLD" || ICON="$ICO_SUNNY"
    else
        (( TEMP < 10 )) && ICON="$ICO_NIGHT$ICO_COLD" || ICON="$ICO_NIGHT"
    fi
    CLASS="clear"
else
    $IS_DAY && ICON="$ICO_SUNNY" || ICON="$ICO_NIGHT"; CLASS="ok"
fi

TOOLTIP="$CONDITION\n$TEMP_STR  |  Humidity: $HUMIDITY  |  Wind: $WIND"

echo "{\"text\": \"$ICON  $TEMP_STR\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"
