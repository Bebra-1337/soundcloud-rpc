import QtQuick

// Orbit: the cover as a planet, the track's progress as a satellite on a fine elliptical orbit around it. The orbit
// passes behind the planet and in front of it.
ThemeBase {
    id: root
    readonly property real cx: 70 * u
    readonly property real cy: 50 * u
    readonly property real ringW: 124 * u
    readonly property real ratio: 0.24
    readonly property real ang: -Math.PI / 2 + Math.PI * 2 * progress
    readonly property real line: Math.max(1, 0.3 * u)

    background: [
        Rectangle { anchors.fill: parent; color: root.bg },
        // the planet lights its surroundings
        Glow {
            x: (root.width - 286 * root.u) / 2 + root.cx - width / 2
            y: (root.height - 100 * root.u) / 2 + root.cy - height / 2
            width: 150 * root.u; height: width
            strength: root.light ? 0.16 : 0.13
        }
    ]

    // back half of the orbit, then the planet, then the front half
    Ring {
        x: root.cx - width / 2; y: root.cy - height / 2; width: root.ringW; height: root.ringW
        ratio: root.ratio; half: -1; value: root.progress; lineWidth: root.line; z: 0
    }
    Cover {
        x: root.cx - width / 2; y: root.cy - height / 2
        width: 46 * root.u; height: width; radius: width / 2
        source: root.cover; z: 1; shadowStrength: 0.8
    }
    Ring {
        x: root.cx - width / 2; y: root.cy - height / 2; width: root.ringW; height: root.ringW
        ratio: root.ratio; half: 1; value: root.progress; lineWidth: root.line; z: 2
    }
    // the satellite: an accent point with a ring of the background around it, so it reads over the orbit line
    Rectangle {
        readonly property real r: root.ringW / 2 - root.line
        width: 2.6 * root.u; height: width; radius: width / 2
        color: root.accent
        border.color: root.bg; border.width: Math.max(1, 0.5 * root.u)
        x: root.cx + r * Math.cos(root.ang) - width / 2
        y: root.cy + r * root.ratio * Math.sin(root.ang) - height / 2
        z: Math.sin(root.ang) > 0 ? 3 : 0
    }
    TrackInfo {
        x: 148 * root.u
        y: (100 * root.u - height) / 2
        width: 124 * root.u
        unit: root.u
        theme: root
        titleSize: 8.6
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
