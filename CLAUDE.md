# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A single-file desktop SoundCloud client (`soundcloud_rpc.py`, PySide6/QtWebEngine) that publishes Discord Rich Presence, exposes MPRIS over D-Bus, and lives in the system tray. Linux-only, packaged via a Nix flake. There is no test suite or linter.

## Commands

```bash
nix develop                      # dev shell with pyside6 + pypresence (nix-shell uses shell.nix, pinned to flake.lock's nixpkgs)
python3 soundcloud_rpc.py        # run (add --minimized / -m to start in tray)
nix run                          # build and run the packaged app
nix build                        # produces ./result
```

If you add a Python dependency or a new asset file, update `flake.nix` too: the dependency list is duplicated in the package and the devShell, and the installPhase copies files explicitly.

## Architecture

Everything lives in `SoundCloudClient(QMainWindow)`. Data flow for Rich Presence:

1. **JS observer** (`observer_js_code` in `__init__`) is injected into the page via `runJavaScript`. It scrapes the SoundCloud player bar DOM (CSS selectors like `.playControls`, `.playbackSoundBadge__title`) with a debounced `MutationObserver`, and reports by `console.log("SOUNDCLOUD_RPC_UPDATE:" + JSON)`. When the player bar is absent it emits a `debug: true` payload.
2. **`SoundCloudWebPage.javaScriptConsoleMessage`** picks up those console messages and forwards the payload to `handle_js_result`. The console is the JS→Python channel.
3. **`poll_state`** (3s `QTimer`) re-injects the observer, because SPA navigation and reloads drop it (the script guards itself with `window.soundcloud_rpc_observer_set` and disconnects the previous `MutationObserver` on re-init).
4. **`handle_js_result`** turns the payload into a *desired activity* dict and hands it to `DiscordRpcWorker.set_activity`. It only holds the 3-consecutive-`debug` idle debounce (`idle_count`) and the Paused/Playing mapping.
5. **`DiscordRpcWorker`** (own thread + asyncio loop) owns the pypresence connection so blocking IPC never freezes the GUI. It always converges to the latest desired activity, dedupes (`_same`, tolerating <5s timestamp drift), rate limits to 2.5s (a throttled update is delayed, never dropped), reconnects with 5s backoff and re-sends after reconnect. `DiscordError` (payload rejected) does not tear down the connection. `clean_rpc_text` enforces Discord's 2..128 byte limit on details/state, since violating it used to cause reconnect loops.

Other pieces:

- **MPRIS**: `MprisAdaptor` and `MprisPlayerAdaptor` are `QDBusAbstractAdaptor`s registered on the session bus as `org.mpris.MediaPlayer2.soundcloud_rpc`. Playback control works by running JS that clicks the site's own player buttons (`trigger_*` methods). `playback_status` is updated by `handle_js_result`.
- **Bot-detection bypass**: the profile's User-Agent has the `QtWebEngine/x.y` token stripped, and a `stealth` script is injected at DocumentCreation (webdriver, `window.chrome`, plugins, languages). Cloudflare/DataDome blocks are the reason; don't remove these casually.
- **Ad blocking**: `AdBlockInterceptor` (network level) plus an injected CSS script (visual only). The comments in the code note that network-level blocking can break integrity checks, so keep it conservative.
- **Navigation**: `SoundCloudWebPage` and `SoundCloudExternalPage` route non-SoundCloud links (and `gate.sc` redirects, via `resolve_target_url` / `is_internal_soundcloud_host`) to the system browser.
- **Discord IPC**: `DiscordRpcWorker._connect` tries the default pipe first, then falls back to Flatpak paths (`$XDG_RUNTIME_DIR/app/com.discordapp.Discord`, `dev.vencord.Vesktop`). The asset keys used for images (`bw-exploring-bordered-white`, `bw-icon-bordered-white`) belong to the Discord application `client_id`.
- **Window lifecycle**: closing the window hides it to the tray; only `quit_app` (which sets `really_quit`) exits.
- Profile storage (login/cookies) persists in `~/.config/soundcloud_rpc/storage`.
