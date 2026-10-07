pragma Singleton
import QtQuick
import ScBackend

// Colors of the main UI. Three sources, picked by `App.colorMode` (tray: Appearance):
//  - system: the Qt palette (qt6ct on Linux, which follows the desktop theme live through ThemeWatcher). Only the
//    window, text and accent colors are taken as they are; the surfaces, hovers and outlines between them are
//    mixed from those, which works for dark and light schemes alike.
//  - dark / light: SoundCloud's own colors from its media kit (black #121212, white #FAFAFA, orange #FF5500),
//    with the same mixes between them.
//  - auto (default): system where the desktop palette is in use (Linux with qt6ct), otherwise dark.
// The idle themes keep their own grayscale look.
QtObject {
    id: style

    readonly property SystemPalette system: SystemPalette { colorGroup: SystemPalette.Active }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }
    function luminance(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }
    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // SoundCloud media kit
    readonly property color brandOrange: "#ff5500"
    readonly property color brandBlack: "#121212"
    readonly property color brandWhite: "#fafafa"

    readonly property bool followSystem: App.colorMode === "system" || (App.colorMode === "auto" && App.systemPaletteDefault)
    readonly property bool light: !followSystem && App.colorMode === "light"

    readonly property color bg: followSystem ? system.window : (light ? brandWhite : brandBlack)
    readonly property color ink: followSystem ? system.windowText : (light ? brandBlack : brandWhite)
    readonly property bool isLight: luminance(bg) > 0.5   // for effects that must flip with the scheme
    readonly property color panel: mix(bg, ink, 0.03)     // rail and Now Playing column
    readonly property color surface: mix(bg, ink, 0.06)   // hovered / current rows
    readonly property color raised: mix(bg, ink, 0.10)    // chips, placeholders, menus
    readonly property color hover: mix(bg, ink, 0.15)
    readonly property color outline: mix(bg, ink, 0.22)
    readonly property color inkDim: mix(ink, bg, 0.30)
    readonly property color inkFaint: mix(ink, bg, 0.55)
    // the rail's glyph: white on dark colors, black on light ones, unless chosen in the settings
    readonly property url logo: App.logoStyle === "black" || (App.logoStyle === "auto" && isLight) ? "qrc:/logo-dark.png"
                                                                                                    : "qrc:/logo.png"
    readonly property color accent: followSystem ? system.accent : brandOrange
    readonly property color accentHover: luminance(accent) > 0.5 ? Qt.darker(accent, 1.12) : Qt.lighter(accent, 1.25)
    // text and icons on accent-filled buttons: the brand's black on orange, or for a system accent the window color
    // or the brightest text, whichever stands out more
    readonly property color onAccent: !followSystem ? brandBlack
                                      : Math.abs(luminance(accent) - luminance(bg)) > Math.abs(luminance(accent) - luminance(system.highlightedText))
                                        ? bg : system.highlightedText

    // artwork URLs that already failed to load, so recreated delegates don't request them again
    readonly property var missingArt: ({})

    readonly property int gutter: 24
    readonly property int tipDelay: 1000  // ms the pointer rests on something before its tooltip shows
    readonly property int railWidth: 68
    readonly property int panelWidth: 360

    function fmtTime(ms) {
        if (!(ms > 0))
            return "0:00"
        const s = Math.floor(ms / 1000)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = s % 60
        return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function fmtCount(n) {
        if (n >= 1e6)
            return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + "M"
        if (n >= 1e3)
            return (n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + "K"
        return "" + (n || 0)
    }

    function isCollection(item) {
        return item && (item.kind === "playlist" || item.kind === "system-playlist" || item.kind === "station")
    }

    function subtitle(item) {
        if (!item)
            return ""
        switch (item.kind) {
        case "track":
            return item.artist + (item.repostedBy ? "   ↻ " + item.repostedBy : "")
        case "user":
            //: %1 is the count, shortened like 1.2K; the plural form follows the exact number
            return item.followers ? qsTr("%1 followers", "", item.followers).arg(Style.fmtCount(item.followers)) : (item.artist || qsTr("Artist"))
        case "system-playlist":
        case "station":
            return item.artist || "SoundCloud"
        default:
            return (item.isAlbum ? qsTr("Album") : qsTr("Playlist")) + (item.artist ? " · " + item.artist : "")
        }
    }
}
