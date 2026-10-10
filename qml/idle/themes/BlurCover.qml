import QtQuick

// Ambient: the cover's own colors fill the room, the cover sits large on the left, the title is set big and quiet
// beside it. Status on top, progress on the cover's bottom line.
ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; veil: root.light ? 0.5 : 0.42; saturation: 0.15 },
        // the text side settles a little toward the background
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.alpha(root.bg, 0) }
                GradientStop { position: 0.45; color: root.alpha(root.bg, 0.1) }
                GradientStop { position: 1.0; color: root.alpha(root.bg, 0.4) }
            }
        }
    ]

    Cover {
        id: art
        x: 14 * root.u; y: 14 * root.u
        width: 72 * root.u; height: width
        radius: 1.4 * root.u
        source: root.cover
        shadowStrength: 0.85
    }
    NowPlaying {
        x: 104 * root.u; y: art.y
        width: 168 * root.u
        unit: root.u
        playing: root.playing
    }
    TrackInfo {
        x: 104 * root.u
        y: art.y + art.height - height + 0.9 * root.u
        width: 168 * root.u
        unit: root.u
        theme: root
        titleSize: 11
        pausedLabel: false  // the status label above says it
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
