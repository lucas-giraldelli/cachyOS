#!/usr/bin/env python3
import json, os, sys, time
from urllib.request import urlopen

CACHE = os.path.expanduser("~/.cache/waybar-weather")
LOC_F = f"{CACHE}/location.json"
WX_F  = f"{CACHE}/current.json"

ICONS_D = {
    0:"󰖜",1:"󰖜",2:"󰖖",3:"󰖐",
    45:"󰖑",48:"󰖑",
    51:"󰖘",53:"󰖘",55:"󰖗",56:"󰖘",57:"󰖗",
    61:"󰖘",63:"󰖘",65:"󰖗",66:"󰖘",67:"󰖗",
    71:"󰖙",73:"󰖙",75:"󰖚",77:"󰖙",
    80:"󰖘",81:"󰖘",82:"󰖗",85:"󰖙",86:"󰖚",
    95:"󰖔",96:"󰖔",99:"󰖔",
}
ICONS_N = {**ICONS_D, 0:"󰖕",1:"󰖕",2:"󰖕"}

CSS = {
    0:"clear",1:"clear",2:"cloudy",3:"cloudy",
    45:"fog",48:"fog",
    51:"rain",53:"rain",55:"rain",56:"rain",57:"rain",
    61:"rain",63:"rain",65:"rain",66:"rain",67:"rain",
    71:"snow",73:"snow",75:"snow",77:"snow",
    80:"rain",81:"rain",82:"rain",85:"snow",86:"snow",
    95:"storm",96:"storm",99:"storm",
}

DESC = {
    0:"Céu limpo",1:"Predominantemente limpo",2:"Parcialmente nublado",
    3:"Nublado",45:"Neblina",48:"Neblina com gelo",
    51:"Garoa leve",53:"Garoa moderada",55:"Garoa intensa",
    56:"Garoa congelante leve",57:"Garoa congelante intensa",
    61:"Chuva leve",63:"Chuva moderada",65:"Chuva forte",
    66:"Chuva congelante leve",67:"Chuva congelante forte",
    71:"Neve leve",73:"Neve moderada",75:"Neve forte",77:"Grânulos de neve",
    80:"Pancadas leves",81:"Pancadas moderadas",82:"Pancadas fortes",
    85:"Pancadas de neve leves",86:"Pancadas de neve fortes",
    95:"Trovoada",96:"Trovoada c/ granizo",99:"Trovoada c/ granizo forte",
}

def fetch(url):
    try:
        with urlopen(url, timeout=5) as r:
            return json.loads(r.read())
    except Exception:
        return None

def err():
    print(json.dumps({"text":"󰖑  --°C","class":"error","tooltip":"Clima indisponível"}))
    sys.exit(0)

def get_loc():
    if os.path.exists(LOC_F):
        try:
            d = json.load(open(LOC_F))
            if time.time() - d.get("ts", 0) < 86400:
                return d
        except Exception:
            pass
    d = fetch("http://ip-api.com/json/?fields=lat,lon,city,country")
    if d and "lat" in d:
        d["ts"] = time.time()
        os.makedirs(CACHE, exist_ok=True)
        json.dump(d, open(LOC_F, "w"))
        return d

# Serve from cache when fresh
if os.path.exists(WX_F):
    try:
        c = json.load(open(WX_F))
        if time.time() - c.get("ts", 0) < 600:
            print(c["out"])
            sys.exit(0)
    except Exception:
        pass

loc = get_loc()
if not loc:
    err()

url = (
    f"https://api.open-meteo.com/v1/forecast"
    f"?latitude={loc['lat']}&longitude={loc['lon']}"
    f"&current=temperature_2m,apparent_temperature,relative_humidity_2m,"
    f"wind_speed_10m,weather_code,is_day"
    f"&wind_speed_unit=kmh&temperature_unit=celsius&timezone=auto"
)
data = fetch(url)
if not data or "current" not in data:
    err()

cur  = data["current"]
code = cur.get("weather_code", 0)
iday = cur.get("is_day", 1)
temp = round(cur.get("temperature_2m", 0))
feel = round(cur.get("apparent_temperature", 0))
hum  = cur.get("relative_humidity_2m", 0)
wind = cur.get("wind_speed_10m", 0)

icon = (ICONS_D if iday else ICONS_N).get(code, "󰖜")
cls  = CSS.get(code, "ok")
desc = DESC.get(code, "Desconhecido")

if cls == "clear" and temp < 10:
    icon += "󰹶"

tip = f"{desc}\n{temp}°C (sensação {feel}°C)  |  Umidade: {hum}%  |  Vento: {wind:.0f} km/h"
out = json.dumps({"text": f"{icon}  {temp}°C", "class": cls, "tooltip": tip})

os.makedirs(CACHE, exist_ok=True)
json.dump({"ts": time.time(), "out": out}, open(WX_F, "w"))
print(out)
