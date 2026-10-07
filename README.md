# SoundCloud Desktop Player

A native desktop client for **SoundCloud** (C++ / Qt Quick) with Discord Rich Presence, MPRIS D-Bus controls and a system tray. You sign in with your own SoundCloud account; the client shows the same Home, Feed and Library as soundcloud.com in its own player instead of the website.

![SoundCloud Desktop](soundcloud.png)

---

## ✨ Features

- 🎵 **Native player**: Home (recently played + SoundCloud's selections), Feed, Library (likes, playlists & albums, history, following), Search (or paste a soundcloud.com link), playlist/album and artist pages, a play queue with shuffle/repeat and autoplay of related tracks, likes, and a SoundCloud-style waveform seek bar. No embedded website: pages are Qt Quick, audio is played by QtMultimedia (FFmpeg).
- 🔐 **Your own account**: signing in happens once on soundcloud.com's own sign-in page in a small window; the session token is then kept in `~/.config/soundcloud_rpc/token` (mode 0600). *Sign Out* is in the tray menu.
- 🎧 **Discord Rich Presence**: track title, artist, artwork, exact elapsed/remaining time and a "Listen on SoundCloud" button.
- 🎛️ **MPRIS D-Bus**: media keys, playerctl and desktop widgets (Waybar, Noctalia, KDE Plasma, GNOME), including seeking, volume, shuffle and loop.
- 📌 **System tray**: closing the window keeps playing in the background; Play/Pause, Next/Previous, Copy Track Link, Idle Screen, Sign Out, Quit.
- 🌌 **Idle Screen**: click the cover (or the screen button, or `Ctrl+I`) for a full-window "now playing" scene with 15 grayscale themes; some react to the actual music (spectrum, stereo channels, kicks). A click or key press returns.
- ⌨️ **Shortcuts**: `Space` play/pause, `←/→` seek 5 s, `Ctrl+←/→` previous/next, `Ctrl+F` search, `Ctrl+L` like, `Ctrl+Shift+C` copy track link, `Esc` back.

> Tracks that SoundCloud only serves with DRM (Widevine, part of the major-label catalogue) can't be played by this client; they are marked with a lock and skipped. Go+ previews play their 30-second snippet, like on the site.

---

## 🛠️ Usage & Running

### NixOS / Nix (Recommended)

Run directly:
```bash
nix run github:Bebra-1337/soundcloud-rpc
```

Add it to your system flake:
```nix
{
  inputs.soundcloud-rpc = {
    url = "github:Bebra-1337/soundcloud-rpc";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # in your NixOS configuration (specialArgs must pass `inputs`):
  environment.systemPackages = [
    inputs.soundcloud-rpc.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```
(or with Home Manager: `home.packages = [ ... ];`). The package installs the `soundcloud-rpc` executable, a `.desktop` entry and the icon, so it shows up in application launchers.

Alternatively use the overlay, which builds the package against your own `pkgs`:
```nix
nixpkgs.overlays = [ inputs.soundcloud-rpc.overlays.default ];
environment.systemPackages = [ pkgs.soundcloud-rpc ];
```

### Development Shell

```bash
nix develop   # or, without flakes: nix-shell
cmake -B build -G Ninja && cmake --build build
./build/soundcloud-rpc
```

Preview all idle themes with fake data (←/→ switch theme, Space play/pause, T long title, C no cover, A auto-cycle, M fake music):
```bash
./build/soundcloud-rpc-preview --fixed --size 1431x500 --music
```

---

## ⚙️ Command-Line Flags

```text
Usage: soundcloud-rpc [options] [url...]

Options:
  -h, --help                   Displays help.
  -v, --version                Displays version information.
  -m, -t, --minimized, --tray  Start application minimized to system tray

Arguments:
  url                          SoundCloud links to open
```

---

## 📄 License

MIT License.
