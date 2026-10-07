import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root
    property real warp: 0
    NumberAnimation on warp { from: 0; to: 1; duration: 7000; loops: Animation.Infinite; running: root.playing }
    readonly property real cx: (width - 286 * u) / 2 + 58 * u
    readonly property real cy: height / 2

    background: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#000000" }
                GradientStop { position: 1; color: "#0f0f0f" }
            }
        },
        Repeater {
            model: 240
            Rectangle {
                readonly property real a: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1 * Math.PI * 2
                readonly property real off: Math.abs(Math.sin(index * 78.233) * 12345.678) % 1
                readonly property real p: (root.warp + off) % 1
                readonly property real dist: (0.12 + Math.pow(p, 2.2)) * root.width * 0.8
                x: root.cx + Math.cos(a) * dist; y: root.cy + Math.sin(a) * dist * 0.6
                width: (0.25 + p * 0.95) * root.u; height: width; radius: width / 2
                color: "white"; opacity: Math.min(1, p * 2.2)
            }
        },
        Vignette { strength: 0.5 },
        Grain { }
    ]

    Item {
        x: 30 * root.u; y: 22 * root.u; width: 56 * root.u; height: width
        Repeater {
            model: 2
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: width; radius: width / 2
                color: "transparent"; border.color: "white"; border.width: 1
                property real ph: index * 0.5
                NumberAnimation on ph { from: 0; to: 1; duration: 5200; loops: Animation.Infinite; running: root.playing }
                scale: 1 + (ph % 1) * 0.55
                opacity: (1 - (ph % 1)) * 0.35
            }
        }
        Cover { anchors.fill: parent; radius: width / 2; source: root.cover; shadowStrength: 0.8 }
    }
    TrackInfo {
        x: 106 * root.u
        y: (100 * root.u - height) / 2
        width: 167 * root.u
        unit: root.u; titleSize: 9
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
