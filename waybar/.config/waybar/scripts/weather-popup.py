#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import json, os, time, threading
from datetime import datetime
from urllib.request import urlopen

CACHE = os.path.expanduser("~/.cache/waybar-weather")
LOC_F = f"{CACHE}/location.json"
POP_F = f"{CACHE}/popup.json"
POP_TTL = 300  # 5 min

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

WIND_ARR = ["↑","↗","→","↘","↓","↙","←","↖"]

CSS_DATA = b"""
    .temp-big  { font-size:34px; font-weight:bold; color:#c0caf5; }
    .icon-big  { font-size:28px; }
    .cond-lbl  { color:#a9b1d6; font-size:12px; }
    .loc-lbl   { color:#7aa2f7; font-size:11px; font-weight:bold; }
    .highlow   { color:#565f89; font-size:11px; }
    .det-label { color:#565f89; font-size:11px; }
    .det-value { color:#c0caf5; font-size:11px; font-weight:bold; }
    .sec-title { color:#565f89; font-size:10px; font-style:italic; }
    .h-time    { color:#565f89; font-size:10px; }
    .h-icon    { font-size:15px; }
    .h-temp    { color:#a9b1d6; font-size:11px; }
    .status    { color:#e0af68; font-size:11px; }
"""

def fetch_json(url):
    try:
        with urlopen(url, timeout=8) as r:
            return json.loads(r.read())
    except Exception:
        return None

def get_loc():
    if os.path.exists(LOC_F):
        try:
            d = json.load(open(LOC_F))
            if time.time() - d.get("ts", 0) < 86400:
                return d
        except Exception:
            pass
    d = fetch_json("http://ip-api.com/json/?fields=lat,lon,city,country")
    if d and "lat" in d:
        d["ts"] = time.time()
        os.makedirs(CACHE, exist_ok=True)
        json.dump(d, open(LOC_F, "w"))
        return d

def get_weather(lat, lon):
    if os.path.exists(POP_F):
        try:
            c = json.load(open(POP_F))
            if time.time() - c.get("ts", 0) < POP_TTL:
                return c["data"]
        except Exception:
            pass
    url = (
        f"https://api.open-meteo.com/v1/forecast"
        f"?latitude={lat}&longitude={lon}"
        f"&current=temperature_2m,apparent_temperature,relative_humidity_2m,"
        f"wind_speed_10m,wind_direction_10m,weather_code,surface_pressure,"
        f"precipitation,uv_index,is_day"
        f"&hourly=temperature_2m,weather_code"
        f"&daily=sunrise,sunset,temperature_2m_max,temperature_2m_min"
        f"&wind_speed_unit=kmh&temperature_unit=celsius&timezone=auto&forecast_days=2"
    )
    data = fetch_json(url)
    if data:
        os.makedirs(CACHE, exist_ok=True)
        json.dump({"ts": time.time(), "data": data}, open(POP_F, "w"))
    return data

def wind_arrow(deg):
    return WIND_ARR[int((deg + 22.5) / 45) % 8]

def make_detail_col(pairs):
    vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    for label, value in pairs:
        cell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        lw = Gtk.Label(label=label)
        lw.get_style_context().add_class("det-label")
        lw.set_xalign(0)
        vw = Gtk.Label(label=value)
        vw.get_style_context().add_class("det-value")
        vw.set_xalign(0)
        cell.pack_start(lw, False, False, 0)
        cell.pack_start(vw, False, False, 0)
        vbox.pack_start(cell, False, False, 0)
    return vbox


class WeatherPopup(Gtk.Window):
    def __init__(self):
        super().__init__(title="Clima")
        self.set_keep_above(True)
        self.set_resizable(False)
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        self.set_size_request(320, -1)

        css = Gtk.CssProvider()
        css.load_from_data(CSS_DATA)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(outer)

        hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        hdr.set_margin_top(4)
        hdr.set_margin_start(10)
        hdr.set_margin_end(4)
        self.status = Gtk.Label(label="")
        self.status.set_xalign(0)
        self.status.get_style_context().add_class("status")
        btn = Gtk.Button(label="✕")
        btn.set_relief(Gtk.ReliefStyle.NONE)
        btn.connect("clicked", lambda _: Gtk.main_quit())
        hdr.pack_start(self.status, True, True, 0)
        hdr.pack_end(btn, False, False, 0)
        outer.pack_start(hdr, False, False, 0)

        self.body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.body.set_margin_start(14)
        self.body.set_margin_end(14)
        self.body.set_margin_bottom(12)
        outer.pack_start(self.body, True, True, 0)

        self._load()

    def _load(self):
        self.status.set_text("↻ carregando...")
        threading.Thread(target=self._fetch, daemon=True).start()

    def _fetch(self):
        loc = get_loc()
        if not loc:
            GLib.idle_add(self.status.set_text, "Localização indisponível")
            return
        wx = get_weather(loc["lat"], loc["lon"])
        if not wx:
            GLib.idle_add(self.status.set_text, "Clima indisponível")
            return
        GLib.idle_add(self._build, loc, wx)

    def _build(self, loc, wx):
        self.status.set_text("")
        cur   = wx["current"]
        daily = wx["daily"]
        hrly  = wx["hourly"]

        code  = cur.get("weather_code", 0)
        is_day = cur.get("is_day", 1)
        temp  = round(cur.get("temperature_2m", 0))
        feel  = round(cur.get("apparent_temperature", 0))
        hum   = cur.get("relative_humidity_2m", 0)
        wspd  = cur.get("wind_speed_10m", 0)
        wdir  = cur.get("wind_direction_10m", 0)
        pres  = cur.get("surface_pressure", 0)
        prec  = cur.get("precipitation", 0)
        uv    = cur.get("uv_index", 0)

        icon  = (ICONS_D if is_day else ICONS_N).get(code, "󰖜")
        desc  = DESC.get(code, "Desconhecido")
        t_max = round(daily["temperature_2m_max"][0])
        t_min = round(daily["temperature_2m_min"][0])
        rise  = daily["sunrise"][0][11:16]
        sset  = daily["sunset"][0][11:16]

        # ── top row: icon+temp  /  location+high-low
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        top.set_margin_top(8)

        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        il = Gtk.Label(label=icon); il.get_style_context().add_class("icon-big"); il.set_xalign(0)
        tl = Gtk.Label(label=f"{temp}°C"); tl.get_style_context().add_class("temp-big"); tl.set_xalign(0)
        left.pack_start(il, False, False, 0)
        left.pack_start(tl, False, False, 0)
        top.pack_start(left, False, False, 0)

        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        right.set_valign(Gtk.Align.END)
        ll = Gtk.Label(label=f"{loc.get('city','')}, {loc.get('country','')}")
        ll.get_style_context().add_class("loc-lbl"); ll.set_xalign(1)
        hl = Gtk.Label(label=f"↑{t_max}°  ↓{t_min}°")
        hl.get_style_context().add_class("highlow"); hl.set_xalign(1)
        right.pack_start(ll, False, False, 0)
        right.pack_start(hl, False, False, 0)
        top.pack_end(right, False, False, 0)
        self.body.pack_start(top, False, False, 0)

        # condition + feels like
        cl = Gtk.Label(label=f"{desc}  •  Sensação {feel}°C")
        cl.get_style_context().add_class("cond-lbl"); cl.set_xalign(0)
        self.body.pack_start(cl, False, False, 0)

        self.body.pack_start(Gtk.Separator(), False, False, 2)

        # ── details: two columns of label/value stacks
        det_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        det_row.pack_start(make_detail_col([
            ("Umidade",       f"{hum}%"),
            ("Vento",         f"{wspd:.0f} km/h {wind_arrow(wdir)}"),
            ("UV",            f"{uv:.1f}"),
        ]), True, True, 0)
        det_row.pack_start(make_detail_col([
            ("Pressão",       f"{pres:.0f} hPa"),
            ("Precipitação",  f"{prec:.1f} mm"),
            ("Nascer / Pôr",  f"{rise} / {sset}"),
        ]), True, True, 0)
        self.body.pack_start(det_row, False, False, 0)

        self.body.pack_start(Gtk.Separator(), False, False, 2)

        # ── hourly forecast
        sec = Gtk.Label(label="Próximas horas")
        sec.get_style_context().add_class("sec-title"); sec.set_xalign(0)
        self.body.pack_start(sec, False, False, 0)

        now     = datetime.now()
        now_str = now.strftime("%Y-%m-%dT%H:00")
        times   = hrly.get("time", [])
        h_temps = hrly.get("temperature_2m", [])
        h_codes = hrly.get("weather_code", [])

        start = 0
        for j, t in enumerate(times):
            if t >= now_str:
                start = j
                break

        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        hbox.set_homogeneous(True)

        for h in range(1, 7):
            idx = start + h
            if idx >= len(times):
                break
            dt  = datetime.fromisoformat(times[idx])
            ht  = round(h_temps[idx]) if idx < len(h_temps) else "--"
            hc  = h_codes[idx] if idx < len(h_codes) else 0
            hi  = (ICONS_D if 6 <= dt.hour < 20 else ICONS_N).get(hc, "󰖜")

            col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
            col.set_halign(Gtk.Align.CENTER)
            for txt, cls in [(f"{dt.hour:02d}h","h-time"),(hi,"h-icon"),(f"{ht}°","h-temp")]:
                w = Gtk.Label(label=txt)
                w.get_style_context().add_class(cls)
                col.pack_start(w, False, False, 0)
            hbox.pack_start(col, True, True, 0)

        self.body.pack_start(hbox, False, False, 4)
        self.body.show_all()
        self.resize(320, 1)


win = WeatherPopup()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
