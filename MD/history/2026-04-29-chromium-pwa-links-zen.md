# 2026-04-29 — Chromium PWA: Links externos voltando a abrir no Zen Browser

## Problem

Clicking external links inside the WhatsApp Chromium PWA (`--app=https://web.whatsapp.com`) stopped opening in Zen Browser (the system default) and started opening inside Chromium on the wrong workspace. The behavior regressed around Chromium 132, which shipped **Navigation Capturing** (`PwaNavigationCapturing`) enabled by default on Linux — causing the browser to intercept out-of-scope navigations internally instead of handing them off to `xdg-open`.

---

## Architecture already in place

The setup had a custom three-layer chain to handle external links:

1. **`~/.config/chromium-wa-ext/content.js`** — content script injected into `web.whatsapp.com`; intercepts `click` events on `<a>` elements pointing outside the app's scope and opens the URL via the `waopenin:` custom scheme.

2. **`~/.local/bin/waopenin`** — shell script registered as the `x-scheme-handler/waopenin` handler; strips the scheme prefix and calls `xdg-open` on the real URL.

3. **`xdg-open`** → Zen Browser (system default via `mimeapps.list`).

---

## What broke

Two things had broken simultaneously:

### 1. `window.open('waopenin:url')` stopped triggering the OS handler

In newer Chromium (130+), `window.open()` for custom/unknown URL schemes no longer reliably dispatches to the OS protocol handler — it either creates an internal popup or is silently dropped.

**Fix:** replaced `window.open('waopenin:' + url, '_blank')` with a programmatic `<a>` element click, which still passes custom schemes to `xdg-open` correctly:

```javascript
const a = document.createElement('a');
a.href = 'waopenin:' + url;
a.style.display = 'none';
document.documentElement.appendChild(a);
a.click();
a.remove();
```

### 2. `Icon=` line was accidentally merged into the `--load-extension` path

During an edit to the `whatsapp.desktop` file, the `Icon=whatsapp` line got concatenated onto the `--load-extension` flag, producing:

```
--load-extension=/home/lukesh/.config/chromium-wa-extIcon=whatsapp
```

Chromium reported `Failed to load extension from: .` on every launch — the extension was never loaded, so no links were being intercepted at all.

**Fix:** restored the correct line break in `~/.local/share/applications/whatsapp.desktop`.

---

## Things that did NOT work

- `--disable-features=PwaNavigationCapturing` in the Exec line — the feature is fully shipped in Chromium 147 and the flag no longer has any effect.
- `--disable-features=NavigationCapturingReimpl,WebAppLinkCapturing` — same issue, wrong/stale flag names.
- Downgrading to Chromium 131 — requires also downgrading `icu` (system-wide), which would break too many other packages.

---

## Final state

**`~/.config/chromium-wa-ext/content.js`** — uses `<a>.click()` instead of `window.open()`.

**`~/.local/share/applications/whatsapp.desktop`** — `Icon=` line restored to its own line; `--load-extension` path clean.

No changes to `waopenin.desktop` or `~/.local/bin/waopenin` — those were working correctly throughout.
