#!/usr/bin/env bash
# ===========================================================================
# waybar/scripts/weather.sh — Current weather via Open-Meteo + IP geolocation
#
# Open-Meteo is free, no API key needed, and uses WMO weather codes.
# Location is auto-detected from IP via ipinfo.io (lat/lon).
# Returns JSON with text (bar) and tooltip (hover).
# Waybar calls this every 30 minutes (interval: 1800).
# ===========================================================================

# ---------------------------------------------------------------------------
# WMO weather code → icon + description
# ---------------------------------------------------------------------------
wmo_icon() {
    case $1 in
        0)           echo "☀️  Clear" ;;
        1)           echo "🌤️  Mostly Clear" ;;
        2)           echo "⛅  Partly Cloudy" ;;
        3)           echo "☁️  Overcast" ;;
        45|48)       echo "🌫️  Fog" ;;
        51|53|55)    echo "🌦️  Drizzle" ;;
        56|57)       echo "🌧️  Freezing Drizzle" ;;
        61|63|65)    echo "🌧️  Rain" ;;
        66|67)       echo "🌧️  Freezing Rain" ;;
        71|73|75)    echo "🌨️  Snow" ;;
        77)          echo "🌨️  Snow Grains" ;;
        80|81|82)    echo "🌦️  Showers" ;;
        85|86)       echo "🌨️  Snow Showers" ;;
        95)          echo "⛈️  Thunderstorm" ;;
        96|99)       echo "⛈️  Thunderstorm + Hail" ;;
        *)           echo "🌡️  Unknown" ;;
    esac
}

# ---------------------------------------------------------------------------
# Get lat/lon from IP
# ---------------------------------------------------------------------------
LOC=$(curl -sf --max-time 3 "ipinfo.io" 2>/dev/null)
if [ -z "$LOC" ]; then
    printf '{"text":"offline","tooltip":"No network","class":"offline"}\n'
    exit 0
fi

LAT=$(echo "$LOC" | grep '"loc"' | grep -oP '[\d.-]+(?=,)')
LON=$(echo "$LOC" | grep '"loc"' | grep -oP '(?<=,)[\d.-]+')
CITY=$(echo "$LOC" | grep '"city"' | grep -oP '(?<=: ")[^"]+')
REGION=$(echo "$LOC" | grep '"region"' | grep -oP '(?<=: ")[^"]+')

if [ -z "$LAT" ] || [ -z "$LON" ]; then
    printf '{"text":"N/A","tooltip":"Location unavailable","class":"error"}\n'
    exit 0
fi

# ---------------------------------------------------------------------------
# Query Open-Meteo
# ---------------------------------------------------------------------------
DATA=$(curl -sf --max-time 5 \
    "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,weather_code&temperature_unit=fahrenheit&timezone=auto" \
    2>/dev/null)

if [ -z "$DATA" ]; then
    printf '{"text":"N/A","tooltip":"Weather unavailable","class":"error"}\n'
    exit 0
fi

TEMP=$(echo "$DATA" | grep -oP '"temperature_2m":\K[\d.-]+' | tail -1)
CODE=$(echo "$DATA" | grep -oP '"weather_code":\K\d+' | tail -1)
TEMP_INT=$(printf "%.0f" "${TEMP:-0}")

ICON_DESC=$(wmo_icon "$CODE")
ICON=$(echo "$ICON_DESC" | awk '{print $1}')
DESC=$(echo "$ICON_DESC" | awk '{$1=""; sub(/^ +/,""); print}')

TEXT="${ICON} ${TEMP_INT}°F"
TOOLTIP="${ICON} ${TEMP_INT}°F — ${DESC} in ${CITY}, ${REGION}"

printf '{"text":"%s","tooltip":"%s","class":"ok"}\n' "$TEXT" "$TOOLTIP"
