import QtQuick

// Common contract for every idle theme: the host sets the track properties, the theme only draws.
//
// Themes are designed for a wide banner window (the reference size is 1431x500, ~2.86:1). Content goes
// into a 286x100 "stage" (1 unit `u` = 1% of its height) that is scaled to fit and centered, so other
// window sizes stay correct, only letterboxed. Full-bleed backdrops go into `background`.
Item {
    id: base

    property string title: ""
    property string artist: ""
    property url cover: ""
    property real position: 0
    property real duration: 1
    property bool playing: true

    readonly property real remaining: Math.max(0, duration - position)
    readonly property real progress: duration > 0 ? Math.min(1, position / duration) : 0
    readonly property string elapsedText: fmt(position)
    readonly property string remainingText: "-" + fmt(remaining)
    readonly property real u: Math.max(0.1, Math.min(width / 286, height / 100))

    // Monochrome palette (noctalia "Monochrome"); the cover is the only color on screen.
    readonly property color ink: "#f2f2f2"
    readonly property color inkDim: "#a3a3a3"
    readonly property color inkFaint: "#6b6b6b"
    readonly property color surface: "#111111"
    readonly property color outline: "#3c3c3c"

    default property alias content: stage.data
    property alias background: backdrop.data

    // Slow looping phase 0..2π (60s) for decorative motion. Themes must use integer multipliers so the loop
    // is seamless. Never use it to move covers or text: sub-pixel drift shows up as jitter.
    property real t: 0
    NumberAnimation on t { from: 0; to: Math.PI * 2; duration: 60000; loops: Animation.Infinite }

    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        var m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    clip: true

    Item { id: backdrop; anchors.fill: parent }
    // snapped to whole pixels: a half-pixel offset would make every edge in the theme render soft
    Item {
        id: stage
        width: 286 * base.u; height: 100 * base.u
        x: Math.round((base.width - width) / 2); y: Math.round((base.height - height) / 2)
    }
}
