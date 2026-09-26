# SoundCloud Desktop Player

A desktop client for **SoundCloud** with Discord Rich Presence integration, MPRIS D-Bus controls, system tray support, and ad-blocking capabilities.

![SoundCloud Desktop](soundcloud.png)

---

## ✨ Features

- 🎵 **Full SoundCloud Web Experience**: Built on QtWebEngine with bot-detection bypass.
- 🎧 **Discord Rich Presence**: Displays track title, artist name, elapsed/remaining time, artwork cover, and play/pause status in your Discord activity.
- 🎛️ **Linux MPRIS D-Bus Integration**: Full media keys support & compatibility with Linux desktop status bars/widgets (Waybar, Polybar, Noctalia, KDE Plasma, GNOME).
- 📌 **System Tray Integration**: Background playback, tray context menu with Play/Pause, Show/Hide Window, and Quit actions.
- 📋 **Copy Track Link**: Copy the currently playing song's URL directly to your clipboard from the tray menu.
- 🌌 **Idle Screen**: a round button in the bottom-right corner of the window (or *Idle Screen → Show Idle Screen* in the tray menu) covers the site with a native QML "now playing" scene (cover, title, time remaining) with 15 switchable themes (default: Glass Card, all in grayscale). A click or key press returns to the site, and playback is not interrupted. Pick the theme from the tray menu: *Idle Screen*. Some themes react to the actual music: in *Particles* the glow of the dots follows the bass and kicks release bursts of particles, *Equalizer* draws the real spectrum with falling peaks, and *Stereo Mirror* shows the left and right channels separately (sound that plays in one ear lights up one side).
- 🔍 **Keyboard Shortcut (`Ctrl + F`)**: Instantly focus and select SoundCloud's top search bar.
- 🔗 **External Browser Router**: Links in artist profiles (Instagram, Twitter, Spotify, etc.) and `gate.sc` redirects automatically open in your default desktop browser.
- 🛡️ **Built-in AdBlocker**: Suppresses audio & display promotions without breaking playback.
- 🚀 **Autostart / Minimized Launch**: Supports starting directly in the system tray via `--minimized` (`-m`).

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

Start a development shell with all dependencies (`PySide6`, `pypresence`, QtQuick modules):
```bash
nix develop   # or, without flakes: nix-shell
python3 -m soundcloud_rpc
```

Preview all idle themes with fake data (←/→ switch theme, Space play/pause, T long title, C no cover, A auto-cycle):
```bash
python3 soundcloud_rpc/qml/preview.py                      # add --fixed --size 1431x500 for a fixed-size window
```

---

## ⚙️ Command-Line Flags

```text
usage: soundcloud-rpc [-h] [--minimized]

options:
  -h, --help        Show help message and exit
  --minimized, -m   Start application minimized to system tray
```

---

## 📄 License

MIT License.
