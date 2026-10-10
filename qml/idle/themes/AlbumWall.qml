import QtQuick

// Big cover: the artwork fills the right side of the window edge to edge and dissolves into the background toward
// the text, like a film poster.
ThemeBase {
    id: root
    readonly property real artSize: Math.max(height, 100 * u)

    background: [
        Rectangle { anchors.fill: parent; color: root.bg },
        Image {
            id: hero
            width: root.artSize; height: root.artSize
            x: root.width - width; y: (root.height - height) / 2
            source: root.cover
            sourceSize.width: 1000; sourceSize.height: 1000
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true; mipmap: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 1200 } }
        },
        // the artwork dissolves into the background: long, eased fade from the left edge of the image
        Rectangle {
            x: hero.x - 1; width: hero.width * 0.62; height: root.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.bg }
                GradientStop { position: 0.25; color: root.alpha(root.bg, 0.86) }
                GradientStop { position: 0.55; color: root.alpha(root.bg, 0.45) }
                GradientStop { position: 0.8; color: root.alpha(root.bg, 0.12) }
                GradientStop { position: 1.0; color: root.alpha(root.bg, 0) }
            }
        },
        // a little weight at the foot so the image sits on the window edge
        Rectangle {
            x: hero.x; width: hero.width; y: root.height * 0.7; height: root.height * 0.3
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.alpha(root.bg, 0) }
                GradientStop { position: 1.0; color: root.alpha(root.bg, 0.35) }
            }
        }
    ]

    NowPlaying {
        x: 14 * root.u; y: 14 * root.u
        width: 150 * root.u
        unit: root.u
        playing: root.playing
    }
    TrackInfo {
        x: 14 * root.u
        y: 86 * root.u - height + 0.9 * root.u
        width: 150 * root.u
        unit: root.u
        theme: root
        titleSize: 12
        pausedLabel: false  // the status label above says it
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
