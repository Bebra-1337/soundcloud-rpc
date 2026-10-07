pragma Singleton
import QtQuick

// Colors follow the system's Qt palette (qt6ct here, which Noctalia writes its scheme into), so the client looks
// like the rest of the desktop and follows its theme. Only the window, text and accent colors are taken as they
// are; the surfaces, hovers and outlines between them are mixed from those, which works for dark and light
// schemes alike. The idle themes keep their own grayscale look.
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

    readonly property color bg: system.window
    readonly property color ink: system.windowText
    readonly property color panel: mix(bg, ink, 0.03)     // rail and Now Playing column
    readonly property color surface: mix(bg, ink, 0.06)   // hovered / current rows
    readonly property color raised: mix(bg, ink, 0.10)    // chips, placeholders, menus
    readonly property color hover: mix(bg, ink, 0.15)
    readonly property color outline: mix(bg, ink, 0.22)
    readonly property color inkDim: mix(ink, bg, 0.30)
    readonly property color inkFaint: mix(ink, bg, 0.55)
    readonly property color accent: system.accent
    readonly property color accentHover: luminance(accent) > 0.5 ? Qt.darker(accent, 1.12) : Qt.lighter(accent, 1.25)
    // text and icons on accent-filled buttons: the window color or the brightest text, whichever stands out more
    readonly property color onAccent: Math.abs(luminance(accent) - luminance(bg)) > Math.abs(luminance(accent) - luminance(system.highlightedText))
                                      ? bg : system.highlightedText

    // artwork URLs that already failed to load, so recreated delegates don't request them again
    readonly property var missingArt: ({})

    readonly property int gutter: 24
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
            return item.followers ? Style.fmtCount(item.followers) + " followers" : (item.artist || "Artist")
        case "system-playlist":
        case "station":
            return item.artist || "SoundCloud"
        default:
            return (item.isAlbum ? "Album" : "Playlist") + (item.artist ? " · " + item.artist : "")
        }
    }
}
