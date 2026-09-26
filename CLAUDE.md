# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A desktop SoundCloud client (Python package `soundcloud_rpc/`, all logic in `soundcloud_rpc/app.py`, PySide6/QtWebEngine) that publishes Discord Rich Presence, exposes MPRIS over D-Bus, shows a QML idle screen, and lives in the system tray. Linux-only, packaged via a Nix flake (`package.nix`, `pyproject.toml`). There is no test suite or linter.

## Commands

```bash
nix develop                      # dev shell with pyside6 + pypresence (nix-shell uses shell.nix, pinned to flake.lock's nixpkgs)
python3 -m soundcloud_rpc        # run (add --minimized / -m to start in tray)
python3 soundcloud_rpc/qml/preview.py  # gallery of idle themes with fake data
nix run                          # build and run the packaged app
nix build                        # produces ./result
```

If you add a Python dependency, update `pyproject.toml` (`dependencies`), `package.nix` (`dependencies`), and the devShell `pythonEnv` in `flake.nix` and `shell.nix`. New assets inside `soundcloud_rpc/` must be listed under `[tool.setuptools.package-data]` in `pyproject.toml`. New files must be `git add`ed before `nix build`, since flakes only see tracked files. The QtQuick modules come from `qt6.qtdeclarative` (via `wrapQtAppsHook` in the package, via `QML_IMPORT_PATH` in the dev shells).

## Architecture

Everything lives in `SoundCloudClient(QMainWindow)`. Data flow for Rich Presence:

1. **JS observer** (`observer_js_code` in `__init__`) is injected into the page via `runJavaScript`. It scrapes the SoundCloud player bar DOM (CSS selectors like `.playControls`, `.playbackSoundBadge__title`) with a debounced `MutationObserver`, and reports by `console.log("SOUNDCLOUD_RPC_UPDATE:" + JSON)`. When the player bar is absent it emits a `debug: true` payload.
2. **`SoundCloudWebPage.javaScriptConsoleMessage`** picks up those console messages and forwards the payload to `handle_js_result`. The console is the JS→Python channel.
3. **`poll_state`** (3s `QTimer`) re-injects the observer, because SPA navigation and reloads drop it (the script guards itself with `window.soundcloud_rpc_observer_set` and disconnects the previous `MutationObserver` on re-init).
4. **`handle_js_result`** turns the payload into a *desired activity* dict and hands it to `DiscordRpcWorker.set_activity`. It only holds the 3-consecutive-`debug` idle debounce (`idle_count`) and the Paused/Playing mapping.
5. **`DiscordRpcWorker`** (own thread + asyncio loop) owns the pypresence connection so blocking IPC never freezes the GUI. It always converges to the latest desired activity, dedupes (`_same`, tolerating <5s timestamp drift), waits 0.25s after the last real change so transient UI states collapse into the final one, and rate limits with a sliding window of 4 updates per 20s (Discord allows ~5; a throttled update is delayed, never dropped). The JS side also has a 1s heartbeat so state changes never depend on an observed DOM mutation, reconnects with 5s backoff and re-sends after reconnect. `DiscordError` (payload rejected) does not tear down the connection. `clean_rpc_text` enforces Discord's 2..128 byte limit on details/state, since violating it used to cause reconnect loops.

Other pieces:

- **Idle screen**: after `IDLE_TIMEOUT_MS` (30s) without input while `playback_status == "Playing"` and the window is visible, `enter_idle` shows a `QQuickWidget` (`qml/IdleScreen.qml`, which loads `qml/themes/<Theme>.qml` and gets `title/artist/cover/position/duration/playing` from `handle_js_result` through `push_idle_state`). It is an overlay (`OverlayContainer`) drawn above the webview, and the webview must never be hidden: Chromium treats a hidden page as a background tab and throttles its timers to ~1/s, which starves SoundCloud's audio buffering and makes playback stutter at regular intervals (check with `document.visibilityState` from `runJavaScript`; it must stay `visible` while idle). Input in the site is reported by an injected `activity` script (`SOUNDCLOUD_RPC_ACTIVITY` console message → `note_activity`); input over the idle page is caught by an event filter on `idle_view` only. Do not install a Python event filter on `QApplication`: PySide crashes in `getWrapperForQObject` on non-wrapped QObjects. Theme/enabled/cycle settings live in `QSettings` and the tray's *Idle Screen* menu. Themes are grayscale (Monochrome palette) with the cover as the only color; every theme derives from `themes/ThemeBase.qml`. The client window is always a floating 1431x500 banner (Hyprland rule in the user's config), so themes are designed for a 286x100 "stage" (`u` = 1% of its height) that scales to fit, with full-bleed backdrops in `background`; shared parts are `TrackInfo`, `Cover`, `Progress`, `Grain`, `Vignette`, `BlurBackdrop`, `Shadow`. QML gotchas found the hard way: `MultiEffect` masks only work with an `Item` wrapping the mask `Rectangle` (`layer.enabled`, `visible: false`); the blur radius is in pixels of the item the effect is applied to, so wide blurs need a small item scaled up (see `BlurBackdrop`); masks inside rotating parents render wrongly; `offscreen` rendering cannot draw `MultiEffect`, so verify visuals on the real display. To check themes at the real size run `python3 soundcloud_rpc/qml/preview.py --fixed --size 1431x500` (add `--shots DIR --only Theme,Theme --cover FILE` to save PNGs).

- **MPRIS**: `MprisAdaptor` and `MprisPlayerAdaptor` are `QDBusAbstractAdaptor`s registered on the session bus as `org.mpris.MediaPlayer2.soundcloud_rpc`. Playback control works by running JS that clicks the site's own player buttons (`trigger_*` methods). `playback_status` is updated by `handle_js_result`.
- **Bot-detection bypass**: the profile's User-Agent has the `QtWebEngine/x.y` token stripped, and a `stealth` script is injected at DocumentCreation (webdriver, `window.chrome`, plugins, languages). Cloudflare/DataDome blocks are the reason; don't remove these casually.
- **Ad blocking**: `AdBlockInterceptor` (network level) plus an injected CSS script (visual only). The comments in the code note that network-level blocking can break integrity checks, so keep it conservative.
- **Navigation**: `SoundCloudWebPage` and `SoundCloudExternalPage` route non-SoundCloud links (and `gate.sc` redirects, via `resolve_target_url` / `is_internal_soundcloud_host`) to the system browser.
- **Discord IPC**: `DiscordRpcWorker._connect` tries the default pipe first, then falls back to Flatpak paths (`$XDG_RUNTIME_DIR/app/com.discordapp.Discord`, `dev.vencord.Vesktop`). The asset keys used for images (`bw-exploring-bordered-white`, `bw-icon-bordered-white`) belong to the Discord application `client_id`.
- **Window lifecycle**: closing the window hides it to the tray; only `quit_app` (which sets `really_quit`) exits.
- Profile storage (login/cookies) persists in `~/.config/soundcloud_rpc/storage`.
