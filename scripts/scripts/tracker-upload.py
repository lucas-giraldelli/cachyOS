#!/usr/bin/env python3
"""
Prepare (and with --send, publish) an upload to a UNIT3D private tracker from a
movie or a season folder:

  1. reads the first video with ffprobe and mediainfo (English, full text)
  2. finds the title on TMDB (ids, keywords, English title, year)
  3. builds the release name: Title [Year] SNN res [service] source audio video [DUAL|MULTI]-group
     (TV leaves the year out; DUAL/MULTI only with a Portuguese track)
  4. takes 6 PNG screenshots spread over the episodes and uploads them to the
     image host (ShareX-style endpoint: POST file, Bearer key -> {"link"})
  5. writes the description (config template + clickable thumbnails)
  6. creates the private .torrent (mktorrent) unless one is given with --torrent
  7. checks the tracker for releases of the same TMDB id
  8. prints a preview; everything is kept in ~/.cache/tracker-upload/<name>/

With --send it posts to /api/torrents/upload, downloads the tracker's .torrent
and adds it to qBittorrent (save path = the folder's parent, through path_map)
so it seeds from the files in place.

Config: ~/.config/tracker-upload/config.json (chmod 600, never in the repo):
  {
    "tracker": "https://tracker.example",       # UNIT3D base URL
    "api_key": "...",                           # tracker API key
    "announce": "https://tracker.example/announce/<passkey>",
    "image_host": "https://tracker.example/api/<sharex-proxy>",
    "image_key": "...",
    "tmdb_token": "...",                        # TMDB API Read Access Token
    "qbit": {"url": "http://localhost:8081", "username": "admin", "password": "..."},
    "path_map": {"/host/data": "/data"},        # host path -> qBittorrent container path
    "anonymous": false,
    "description": "optional template, see DEFAULT_TEMPLATE",
    "season_label": "optional, \", Season {season}\" by default"
  }

Usage:
  tracker-upload.py "<folder or video>" [--name NAME] [--group G] [--source WEBRip]
                    [--torrent FILE] [--fresh] [--send]
"""

import argparse, json, os, random, re, shutil, subprocess, sys, uuid
import urllib.request, urllib.parse, urllib.error, http.cookiejar
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "tracker-upload/config.json"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "tracker-upload"
UA = "tracker-upload/1.0"   # Cloudflare in front of the tracker refuses urllib's default
VIDEO = {".mkv", ".mp4", ".avi", ".m2ts", ".ts"}

# UNIT3D ids (default seeds; the same on the tracker)
CATEGORY = {"movie": 1, "tv": 2}
TYPE = {"Full Disc": 1, "Remux": 2, "Encode": 3, "WEB-DL": 4, "WEBRip": 5, "HDTV": 6}
RESOLUTION = {"4320p": 1, "2160p": 2, "1080p": 3, "1080i": 4, "720p": 5, "576p": 6, "576i": 7, "480p": 8, "480i": 9}

SERVICES = ["AMZN", "NF", "DSNP", "HMAX", "MAX", "ATVP", "PCOK", "PMTP", "HULU", "CR", "GLBP", "SKST", "STAN", "iT"]
SOURCES = [(r"remux", "Remux"), (r"web-?dl", "WEB-DL"), (r"webrip", "WEBRip"), (r"\bweb\b", "WEB-DL"),
           (r"blu-?ray|bdrip|brrip", "Encode"), (r"hdtv", "HDTV")]
AUDIO = {"mp3": "MP3", "aac": "AAC", "ac3": "DD", "eac3": "DDP", "dts": "DTS", "truehd": "TrueHD",
         "flac": "FLAC", "opus": "Opus", "vorbis": "Vorbis", "pcm_s16le": "LPCM", "pcm_s24le": "LPCM"}
VIDEO_CODEC = {"h264": "H.264", "hevc": "H.265", "av1": "AV1", "mpeg2video": "MPEG-2", "vc1": "VC-1"}
LANGUAGE = {"por": "Portuguese", "eng": "English", "spa": "Spanish", "jpn": "Japanese", "fre": "French",
            "fra": "French", "ger": "German", "deu": "German", "ita": "Italian", "kor": "Korean", "und": "Unknown"}
CHANNELS = {1: "1.0", 2: "2.0", 3: "2.1", 6: "5.1", 7: "6.1", 8: "7.1"}

DEFAULT_TEMPLATE = """[center][b]{title} ({year}){season_label}[/b][/center]

[b]Episodes:[/b] {episodes}
[b]Video:[/b] {video}, {width}x{height}
[b]Audio:[/b] {audio}
[b]Runtime:[/b] ~{minutes} min
[b]Source:[/b] {source}
[b]Release:[/b] {group}

[center][b]Screenshots[/b]
{screens}
[/center]"""


def die(msg):
    sys.exit(f"tracker-upload: {msg}")


def run(*cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout


def http(url, data=None, headers=None, method=None):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA, **(headers or {})}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        die(f"{method or 'GET'} {url.split('?')[0]}: HTTP {e.code} {e.read()[:300].decode(errors='replace')}")


def multipart(fields, files):
    """fields: {name: str}, files: {name: (filename, bytes, type)} -> (body, content-type)"""
    b = uuid.uuid4().hex
    out = []
    for k, v in fields.items():
        out += [f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n".encode(), str(v).encode(), b"\r\n"]
    for k, (fn, data, ctype) in files.items():
        out += [f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"; filename=\"{fn}\"\r\nContent-Type: {ctype}\r\n\r\n".encode(), data, b"\r\n"]
    out.append(f"--{b}--\r\n".encode())
    return b"".join(out), f"multipart/form-data; boundary={b}"


# --- reading the release -------------------------------------------------------

def videos_of(path):
    if path.is_file():
        return [path]
    vids = sorted(p for p in path.rglob("*") if p.suffix.lower() in VIDEO and "sample" not in p.name.lower())
    if not vids:
        die(f"no video under {path}")
    return vids


def probe(f):
    return json.loads(run("ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(f)))


def parse_name(name):
    """What the folder / file name says: title, year, season, episode, service, source, group."""
    stem = re.sub(r"\.(mkv|mp4|avi|ts|m2ts)$", "", name, flags=re.I)
    clean = stem.replace(".", " ").replace("_", " ")
    m = re.search(r"\bS(\d{1,2})(?:E(\d{1,3}))?\b", clean, re.I)
    y = re.search(r"\b(19\d\d|20\d\d)\b", clean)
    cut = min(x.start() for x in [m, y, re.search(r"\b\d{3,4}p\b", clean)] if x) if (m or y) else len(clean)
    group = re.search(r"-([A-Za-z0-9]+)\]?$", stem) or re.search(r"\[([A-Za-z0-9]+)\]$", stem)
    return {
        "title": re.sub(r"[\[\(].*", "", clean[:cut]).strip(" -"),
        "year": int(y.group(1)) if y else None,
        "season": int(m.group(1)) if m else None,
        "episode": int(m.group(2)) if m and m.group(2) else None,
        "service": next((s for s in SERVICES if re.search(rf"\b{s}\b", clean)), ""),
        "source": next((v for k, v in SOURCES if re.search(k, clean, re.I)), ""),
        "group": group.group(1) if group else "",
    }


def media(first):
    info = probe(first)
    v = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio = [s for s in info["streams"] if s["codec_type"] == "audio"]
    langs = [(s.get("tags") or {}).get("language", "und") for s in audio]
    h, w = int(v["height"]), int(v["width"])
    res = next(r for top, r in [(2400, "4320p"), (1500, "2160p"), (900, "1080p"), (620, "720p"), (540, "576p"), (0, "480p")]
               if h > top or w > top * 16 / 9)
    if v.get("field_order") not in (None, "progressive", "unknown") and res in ("1080p", "576p", "480p"):
        res = res[:-1] + "i"
    a0 = audio[0] if audio else {}
    return {
        "width": w, "height": h, "resolution": res,
        "video": VIDEO_CODEC.get(v["codec_name"], v["codec_name"].upper()),
        "audio": f"{AUDIO.get(a0.get('codec_name'), str(a0.get('codec_name', '')).upper())} {CHANNELS.get(a0.get('channels'), str(a0.get('channels', '')))}".strip(),
        "tracks": [f"{LANGUAGE.get(lang, lang)} ({AUDIO.get(s['codec_name'], s['codec_name'].upper())} {CHANNELS.get(s.get('channels'), '')})"
                   for lang, s in zip(langs, audio)],
        "langs": langs,
        "minutes": round(float(info["format"].get("duration", 0)) / 60),
    }


# --- TMDB ----------------------------------------------------------------------

def tmdb(cfg, path, **params):
    q = urllib.parse.urlencode({k: v for k, v in params.items() if v is not None})
    return json.loads(http(f"https://api.themoviedb.org/3/{path}?{q}",
                           headers={"Authorization": f"Bearer {cfg['tmdb_token']}", "accept": "application/json"}))


def lookup(cfg, kind, title, year, tmdb_id=None):
    if not tmdb_id:
        params = {"query": title, "language": "en-US"}
        params["first_air_date_year" if kind == "tv" else "year"] = year
        hits = tmdb(cfg, f"search/{kind}", **params)["results"] or tmdb(cfg, f"search/{kind}", query=title)["results"]
        if not hits:
            die(f"nothing on TMDB for {kind} '{title}' {year or ''} (pass --tmdb ID)")
        tmdb_id = hits[0]["id"]
    d = tmdb(cfg, f"{kind}/{tmdb_id}", language="en-US", append_to_response="external_ids,keywords")
    ext = d.get("external_ids", {})
    kw = d.get("keywords", {})
    date = d.get("first_air_date" if kind == "tv" else "release_date") or ""
    return {
        "tmdb": tmdb_id,
        "title": d.get("name" if kind == "tv" else "title"),
        "year": int(date[:4]) if date[:4].isdigit() else year,
        "imdb": int((ext.get("imdb_id") or d.get("imdb_id") or "tt0")[2:] or 0),
        "tvdb": ext.get("tvdb_id") or 0,
        "keywords": ", ".join(k["name"] for k in (kw.get("results") or kw.get("keywords") or [])[:8]),
        "anime": "ja" == d.get("original_language") and 16 in [g["id"] for g in d.get("genres", [])],
    }


# --- the pieces ----------------------------------------------------------------

def release_name(kind, show, nm, mi, args):
    if args.name:
        return args.name
    langs = {l for l in mi["langs"] if l != "und"}
    tag = (" MULTI" if len(langs) >= 3 else " DUAL" if len(langs) == 2 else "") if "por" in langs else ""
    se = (f" S{nm['season']:02d}" + (f"E{nm['episode']:02d}" if nm["episode"] else "")) if kind == "tv" else ""
    parts = [re.sub(r"[:/?]", "", show["title"]), "" if kind == "tv" else str(show["year"])]
    parts += [se.strip(), mi["resolution"], nm["service"], args.source or nm["source"], mi["audio"], mi["video"]]
    return re.sub(r"\s+", " ", " ".join(p for p in parts if p)) + tag + f"-{args.group or nm['group'] or 'NoGroup'}"


def screenshots(vids, out, n=6):
    """n frames, spread over the episodes, from 15-85% into each."""
    out.mkdir(parents=True, exist_ok=True)
    picks = [vids[round(i * (len(vids) - 1) / max(n - 1, 1))] for i in range(n)]
    shots = []
    for i, f in enumerate(picks, 1):
        dur = float(probe(f)["format"]["duration"])
        png = out / f"{i}.png"
        run("ffmpeg", "-v", "error", "-y", "-ss", f"{dur * random.uniform(0.15, 0.85):.2f}", "-i", str(f),
            "-frames:v", "1", "-vf", "scale=iw*sar:ih", str(png))
        shots.append(png)
    return shots


def host(cfg, png):
    body, ctype = multipart({}, {"file": (png.name, png.read_bytes(), "image/png")})
    return json.loads(http(cfg["image_host"], body, {"Authorization": f"Bearer {cfg['image_key']}", "Content-Type": ctype}))["link"]


def make_torrent(cfg, path, out):
    if out.exists():
        out.unlink()
    size = sum(p.stat().st_size for p in ([path] if path.is_file() else path.rglob("*")) if p.is_file())
    piece = 24 if size > 16 << 30 else 22 if size > 2 << 30 else 21   # 16 / 4 / 2 MiB
    run("mktorrent", "-p", "-l", str(piece), "-a", cfg["announce"], "-o", str(out), str(path))


def dupes(cfg, kind, show):
    q = urllib.parse.urlencode({"tmdbId": show["tmdb"], "categories[]": CATEGORY[kind], "perPage": 50})
    data = json.loads(http(f"{cfg['tracker']}/api/torrents/filter?{q}",
                           headers={"Authorization": f"Bearer {cfg['api_key']}", "accept": "application/json"}))
    return [t["attributes"]["name"] for t in data.get("data", [])]


def qbit_add(cfg, torrent, save_path):
    q = cfg["qbit"]
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    op.addheaders = [("User-Agent", UA)]
    login = urllib.parse.urlencode({"username": q["username"], "password": q["password"]}).encode()
    if op.open(f"{q['url']}/api/v2/auth/login", login).read() != b"Ok.":
        die("qBittorrent login failed")
    body, ctype = multipart({"savepath": save_path, "autoTMM": "false", "paused": "false", "stopped": "false"},
                            {"torrents": (torrent.name, torrent.read_bytes(), "application/x-bittorrent")})
    op.open(urllib.request.Request(f"{q['url']}/api/v2/torrents/add", body, {"Content-Type": ctype}))


def container_path(cfg, p):
    for host_dir, inside in cfg.get("path_map", {}).items():
        if str(p).startswith(host_dir):
            return inside + str(p)[len(host_dir):]
    return str(p)


# --- main ------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Prepare / send an upload to a UNIT3D tracker.")
    ap.add_argument("path", type=Path)
    ap.add_argument("--name", help="release name, instead of the built one")
    ap.add_argument("--group", help="release group, instead of the one in the name")
    ap.add_argument("--source", choices=list(TYPE), help="instead of the one in the name")
    ap.add_argument("--tmdb", type=int, help="TMDB id, instead of searching")
    ap.add_argument("--torrent", type=Path, help="an existing .torrent of this folder")
    ap.add_argument("--fresh", action="store_true", help="redo screenshots / torrent")
    ap.add_argument("--send", action="store_true", help="upload it and seed it")
    args = ap.parse_args()

    if not CONFIG.exists():
        die(f"no config at {CONFIG} (see the header of this script)")
    cfg = json.loads(CONFIG.read_text())
    for tool in ("ffprobe", "ffmpeg", "mediainfo", "mktorrent"):
        if not shutil.which(tool):
            die(f"{tool} is not installed")

    path = args.path.resolve()
    vids = videos_of(path)
    nm = parse_name(path.name)
    kind = "tv" if nm["season"] is not None else "movie"
    mi = media(vids[0])
    show = lookup(cfg, kind, nm["title"], nm["year"], args.tmdb)
    name = release_name(kind, show, nm, mi, args)
    source = args.source or nm["source"]
    if source not in TYPE:
        die(f"unknown source in '{path.name}': pass --source")

    work = CACHE / re.sub(r"[^\w.-]+", "_", path.name)
    work.mkdir(parents=True, exist_ok=True)
    state_file = work / "state.json"
    state = json.loads(state_file.read_text()) if state_file.exists() and not args.fresh else {}

    if not state.get("screens"):
        state["screens"] = [host(cfg, p) for p in screenshots(vids, work / "screens")]
        state_file.write_text(json.dumps(state, indent=1))
    torrent = args.torrent or work / "release.torrent"
    if not args.torrent and (args.fresh or not torrent.exists()):
        make_torrent(cfg, path, torrent)

    mediainfo = run("mediainfo", vids[0].name, cwd=vids[0].parent, env={**os.environ, "LANG": "C", "LC_ALL": "C"})
    thumbs = [f"[url={u}][img=400]{u}[/img][/url]" for u in state["screens"]]
    description = cfg.get("description", DEFAULT_TEMPLATE).format(
        title=show["title"], year=show["year"], episodes=len(vids), source=source,
        group=args.group or nm["group"] or "NoGroup",
        season=nm["season"] or "",
        season_label=cfg.get("season_label", ", Season {season}").format(season=nm["season"]) if kind == "tv" else "",
        audio=" / ".join(mi["tracks"]), screens="\n".join(" ".join(thumbs[i:i + 2]) for i in range(0, len(thumbs), 2)),
        **{k: mi[k] for k in ("video", "width", "height", "minutes")})

    fields = {
        "name": name, "description": description, "mediainfo": mediainfo, "bdinfo": "",
        "category_id": CATEGORY[kind], "type_id": TYPE[source], "resolution_id": RESOLUTION.get(mi["resolution"], 10),
        "tmdb": show["tmdb"], "imdb": show["imdb"], "tvdb": show["tvdb"], "mal": 0, "igdb": 0,
        "keywords": show["keywords"], "anonymous": int(cfg.get("anonymous", False)),
        "stream": 0, "sd": int(mi["height"] < 720), "personal_release": 0, "internal": 0,
        "season_number": nm["season"] or 0, "episode_number": nm["episode"] or 0,
    }
    (work / "description.bbcode").write_text(description)
    (work / "mediainfo.txt").write_text(mediainfo)
    (work / "fields.json").write_text(json.dumps({k: v for k, v in fields.items() if k not in ("description", "mediainfo")}, indent=1))

    others = dupes(cfg, kind, show)
    print(f"\n{name}\n")
    print(f"  {kind}  TMDB {show['tmdb']}  IMDB {show['imdb']}  TVDB {show['tvdb']}  {show['title']} ({show['year']})")
    print(f"  {source} {mi['resolution']}  {len(vids)} file(s)  torrent {torrent}")
    print(f"  keywords: {show['keywords'] or '-'}")
    print(f"  on the tracker already ({len(others)}):" + "".join(f"\n    {o}" for o in others) if others else "  nothing of it on the tracker yet")
    print(f"\n{description}\n\n  files in {work}")

    if not args.send:
        print("\n  preview only: add --send to upload it")
        return
    body, ctype = multipart({k: str(v) for k, v in fields.items()},
                            {"torrent": ("release.torrent", torrent.read_bytes(), "application/x-bittorrent")})
    res = json.loads(http(f"{cfg['tracker']}/api/torrents/upload", body,
                          {"Authorization": f"Bearer {cfg['api_key']}", "accept": "application/json", "Content-Type": ctype}))
    if not res.get("success"):
        die(f"upload refused: {res.get('message')}")
    got = work / "tracker.torrent"
    got.write_bytes(http(res["data"], headers={"Authorization": f"Bearer {cfg['api_key']}"}))
    qbit_add(cfg, got, container_path(cfg, path.parent))
    print(f"\n  sent: {res.get('message', '')}\n  {res['data']}\n  seeding from {container_path(cfg, path.parent)}")


if __name__ == "__main__":
    main()
