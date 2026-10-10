import QtQuick

// Bokeh: out-of-focus discs of light drift slowly over the cover's colors, like city lights behind a lens. They
// brighten with the music; nothing else reacts. Text on the left, the cover on the right.
ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; veil: root.light ? 0.5 : 0.55; saturation: 0.2 },
        // the discs: soft round lights with the brighter rim a lens gives an out-of-focus point of light
        Repeater {
            model: 11
            Glow {
                readonly property real r1: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
                readonly property real r2: Math.abs(Math.sin(index * 78.233) * 12345.678) % 1
                readonly property real r3: Math.abs(Math.sin(index * 39.425) * 24634.634) % 1
                readonly property int k: 1 + index % 3
                rim: true
                width: (10 + r3 * 24) * root.u; height: width
                x: r1 * root.width - width / 2 + 3 * root.u * Math.sin(root.t * k + index)
                y: r2 * root.height - height / 2 + 4 * root.u * Math.cos(root.t * k + index * 2)
                color: root.light ? "#ffffff" : root.mix(root.accent, "#ffffff", 0.55)
                strength: (root.light ? 0.2 + 0.16 * r2 : 0.05 + 0.05 * r2) * (1 + 1.2 * root.level + 0.6 * root.beat)
            }
        }
    ]

    TrackInfo {
        x: 14 * root.u
        y: 86 * root.u - height + 0.9 * root.u
        width: 162 * root.u
        unit: root.u
        theme: root
        titleSize: 11
        pausedLabel: false  // the status label above says it
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
    NowPlaying {
        x: 14 * root.u; y: 14 * root.u
        width: 162 * root.u
        unit: root.u
        playing: root.playing
    }
    Cover {
        x: 200 * root.u; y: 14 * root.u
        width: 72 * root.u; height: width
        radius: 1.4 * root.u
        source: root.cover
        shadowStrength: 0.85
    }
}
