import QtQuick

ThemeBase {
    id: root
    // fast phase for the fake spectrum (decorative: real audio is not accessible from QtWebEngine)
    property real ph: 0
    NumberAnimation on ph { from: 0; to: Math.PI * 2 * 9; duration: 27000; loops: Animation.Infinite; running: root.playing }

    background: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#1a1a1a" }
                GradientStop { position: 1; color: "#080808" }
            }
        },
        Vignette { strength: 0.6 },
        Grain { }
    ]

    Repeater {
        model: 92
        Rectangle {
            readonly property real env: 1 - Math.pow(Math.abs(index - 20) / 72, 0.8) * 0.75
            readonly property real v: root.playing
                ? Math.abs(Math.sin(root.ph * (1 + index % 3) + index * 0.61) * Math.cos(root.ph * 2 + index * 0.37)) * env
                : 0
            width: (286 - 20) * root.u / 92 - 0.5 * root.u
            x: 10 * root.u + index * (286 - 20) * root.u / 92
            height: Math.max(0.7 * root.u, v * 38 * root.u)
            y: 98 * root.u - height
            radius: width / 2
            Behavior on height { NumberAnimation { duration: 150 } }
            gradient: Gradient {
                GradientStop { position: 0; color: "#f2f2f2" }
                GradientStop { position: 1; color: "#4a4a4a" }
            }
            opacity: 0.9
        }
    }

    Cover {
        x: 14 * root.u + root.driftX; y: 8 * root.u
        width: 54 * root.u; height: width; radius: 2.4 * root.u; source: root.cover
    }
    TrackInfo {
        x: 84 * root.u
        y: 8 * root.u
        width: 187 * root.u
        unit: root.u; titleSize: 9
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
