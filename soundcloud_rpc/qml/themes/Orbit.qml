import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root
    readonly property real cx: 70 * u
    readonly property real cy: 50 * u
    readonly property real ringW: 128 * u
    readonly property real ratio: 0.26
    readonly property real ang: -Math.PI / 2 + Math.PI * 2 * progress

    background: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#060606" }
                GradientStop { position: 1; color: "#141414" }
            }
        },
        Repeater {
            model: 90
            Rectangle {
                readonly property real r1: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
                readonly property real r2: Math.abs(Math.sin(index * 78.233) * 12345.678) % 1
                x: r1 * root.width; y: r2 * root.height
                width: (0.8 + r1 * 1.8) * root.u / 3; height: width; radius: width / 2; color: "white"
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.9; duration: 1500 + r2 * 3000 }
                    NumberAnimation { to: 0.15; duration: 1500 + r1 * 3000 }
                }
            }
        },
        Vignette { strength: 0.5 },
        Grain { }
    ]

    // planet glow
    Rectangle {
        x: root.cx - width / 2 + root.driftX; y: root.cy - height / 2
        width: 60 * root.u; height: width; radius: width / 2; color: "white"; opacity: 0.16
        layer.enabled: true; layer.smooth: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
    }
    Ring {
        x: root.cx - width / 2; y: root.cy - height / 2; width: root.ringW; height: root.ringW
        ratio: root.ratio; half: -1; value: root.progress; color: root.ink; lineWidth: 0.35 * root.u; z: 0
    }
    Rectangle {
        readonly property real r: root.ringW / 2 - 0.35 * root.u
        width: 3.4 * root.u; height: width; radius: width / 2; color: "white"
        x: root.cx + r * Math.cos(root.ang) - width / 2; y: root.cy + r * root.ratio * Math.sin(root.ang) - height / 2
        z: Math.sin(root.ang) > 0 ? 3 : 0
    }
    Cover {
        x: root.cx - width / 2; y: root.cy - height / 2
        width: 44 * root.u; height: width; radius: width / 2; source: root.cover; z: 1; shadowStrength: 0.8
    }
    Ring {
        x: root.cx - width / 2; y: root.cy - height / 2; width: root.ringW; height: root.ringW
        ratio: root.ratio; half: 1; value: root.progress; color: root.ink; lineWidth: 0.35 * root.u; z: 2
    }
    TrackInfo {
        x: 148 * root.u
        y: (100 * root.u - height) / 2
        width: 125 * root.u
        unit: root.u; titleSize: 8
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
