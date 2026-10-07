pragma Singleton
import QtQuick

// Monochrome palette shared with the idle themes; the artwork is the only color on screen.
QtObject {
    readonly property color bg: "#0d0d0d"
    readonly property color panel: "#111111"
    readonly property color surface: "#171717"
    readonly property color raised: "#1f1f1f"
    readonly property color hover: "#262626"
    readonly property color outline: "#2e2e2e"
    readonly property color ink: "#f2f2f2"
    readonly property color inkDim: "#a3a3a3"
    readonly property color inkFaint: "#6b6b6b"
    readonly property color inkOnLight: "#111111"

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
