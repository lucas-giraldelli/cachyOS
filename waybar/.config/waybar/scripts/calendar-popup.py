#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, Pango, GLib
import subprocess, threading, json, os
from datetime import datetime, timedelta, date
from collections import defaultdict

CACHE_FILE = os.path.expanduser("~/.cache/waybar-calendar.json")
CACHE_TTL_HOURS = 1

def fetch_from_gcalcli(months=2):
    today = date.today()
    start = date(today.year, today.month, 1)
    end_month = today.month + months
    end_year = today.year + (end_month - 1) // 12
    end_month = ((end_month - 1) % 12) + 1
    end = date(end_year, end_month, 1)

    out = subprocess.check_output(
        ["gcalcli", "agenda", "--nocolor", "--details", "end",
         "--tsv", start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d")],
        stderr=subprocess.DEVNULL
    ).decode()

    by_day = defaultdict(list)
    for line in out.strip().splitlines():
        parts = line.split("\t")
        if len(parts) < 5 or parts[0] == "start_date" or not parts[1]:
            continue
        try:
            d = datetime.strptime(parts[0], "%Y-%m-%d").date()
            s = datetime.strptime(parts[0] + " " + parts[1], "%Y-%m-%d %H:%M")
            e = datetime.strptime(parts[2] + " " + parts[3], "%Y-%m-%d %H:%M")
            by_day[str(d)].append([parts[4], parts[1], parts[3]])
        except Exception:
            pass
    return by_day

def load_cache():
    if not os.path.exists(CACHE_FILE):
        return None, None
    try:
        with open(CACHE_FILE) as f:
            data = json.load(f)
        updated = datetime.fromisoformat(data["updated"])
        return data["events"], updated
    except Exception:
        return None, None

def save_cache(events):
    data = {"updated": datetime.now().isoformat(), "events": events}
    os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
    with open(CACHE_FILE, "w") as f:
        json.dump(data, f)

def is_stale(updated):
    if updated is None:
        return True
    return (datetime.now() - updated).total_seconds() > CACHE_TTL_HOURS * 3600

class CalendarPopup(Gtk.Window):
    def __init__(self):
        super().__init__(title="Calendário")
        self.set_keep_above(True)
        self.set_resizable(False)
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        self.set_size_request(320, 380)
        self.resize(320, 380)

        css = Gtk.CssProvider()
        css.load_from_data(b"""
            .event-time { color: #7aa2f7; font-weight: bold; }
            .event-title { color: #c0caf5; }
            .dim-label { color: #565f89; font-style: italic; }
            .status { color: #e0af68; font-size: 11px; }
        """)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        self._events = {}

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(vbox)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        header.set_margin_top(4)
        header.set_margin_start(8)
        header.set_margin_end(4)
        self.status_lbl = Gtk.Label(label="")
        self.status_lbl.set_xalign(0)
        self.status_lbl.get_style_context().add_class("status")
        close_btn = Gtk.Button(label="✕")
        close_btn.set_relief(Gtk.ReliefStyle.NONE)
        close_btn.connect("clicked", lambda _: Gtk.main_quit())
        header.pack_start(self.status_lbl, True, True, 0)
        header.pack_end(close_btn, False, False, 0)
        vbox.pack_start(header, False, False, 0)

        self.cal = Gtk.Calendar()
        self.cal.set_margin_top(4)
        self.cal.set_margin_start(8)
        self.cal.set_margin_end(8)
        self.cal.connect("day-selected", self.on_day_selected)
        self.cal.connect("month-changed", self.on_day_selected)
        vbox.pack_start(self.cal, False, False, 0)

        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep.set_margin_top(6)
        vbox.pack_start(sep, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_size_request(-1, 100)

        self.events_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.events_box.set_margin_top(6)
        self.events_box.set_margin_bottom(8)
        self.events_box.set_margin_start(10)
        self.events_box.set_margin_end(10)
        scroll.add(self.events_box)
        vbox.pack_start(scroll, True, True, 0)

        self._load()

    def _load(self):
        events, updated = load_cache()
        if events:
            self._events = events
            self._mark_days()
            self.on_day_selected(self.cal)

        if is_stale(updated):
            self.status_lbl.set_text("↻ atualizando...")
            threading.Thread(target=self._refresh, daemon=True).start()

    def _refresh(self):
        try:
            events = fetch_from_gcalcli()
            save_cache(events)
            GLib.idle_add(self._on_refreshed, events)
        except Exception:
            GLib.idle_add(self.status_lbl.set_text, "")

    def _on_refreshed(self, events):
        self._events = events
        self.status_lbl.set_text("")
        self._mark_days()
        self.on_day_selected(self.cal)

    def _mark_days(self):
        year, month, _ = self.cal.get_date()
        self.cal.clear_marks()
        for key in self._events:
            try:
                d = date.fromisoformat(key)
                if d.year == year and d.month == month + 1:
                    self.cal.mark_day(d.day)
            except Exception:
                pass

    def on_day_selected(self, cal):
        for child in self.events_box.get_children():
            self.events_box.remove(child)

        year, month, day = cal.get_date()
        key = date(year, month + 1, day).isoformat()
        events = self._events.get(key, [])

        if not events:
            lbl = Gtk.Label(label="Sem eventos")
            lbl.set_xalign(0)
            lbl.get_style_context().add_class("dim-label")
            self.events_box.pack_start(lbl, False, False, 0)
        else:
            for title, start_t, end_t in events:
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                time_lbl = Gtk.Label(label=f"{start_t}–{end_t}")
                time_lbl.set_xalign(0)
                time_lbl.set_size_request(110, -1)
                time_lbl.get_style_context().add_class("event-time")
                title_lbl = Gtk.Label(label=title)
                title_lbl.set_xalign(0)
                title_lbl.set_ellipsize(Pango.EllipsizeMode.END)
                title_lbl.set_max_width_chars(22)
                title_lbl.get_style_context().add_class("event-title")
                row.pack_start(time_lbl, False, False, 0)
                row.pack_start(title_lbl, True, True, 0)
                self.events_box.pack_start(row, False, False, 0)

        self.events_box.show_all()

win = CalendarPopup()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
