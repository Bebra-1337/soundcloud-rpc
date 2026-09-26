import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root
    readonly property real cx: width / 2 + driftX
    readonly property real cy: height * 0.42 + driftY
    readonly property real ringW: 78 * u
    readonly property real ratio: 0.28
    readonly property real ang: -Math.PI / 2 + Math.PI * 2 * progress

    Rectangle { anchors.fill: parent; color: "#0c0c0c" }
    Repeater {
        model: 70
        Rectangle {
            readonly property real r1: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
            readonly property real r2: Math.abs(Math.sin(index * 78.233) * 12345.678) % 1
            x: r1 * root.width; y: r2 * root.height
            width: (1 + r1 * 2) ; height: width; radius: width / 2; color: "white"
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.9; duration: 1500 + r2 * 3000 }
                NumberAnimation { to: 0.15; duration: 1500 + r1 * 3000 }
            }
        }
    }

    // glow
    Rectangle {
        x: root.cx - width / 2; y: root.cy - height / 2
        width: 44 * root.u; height: width; radius: width / 2; color: root.accent; opacity: 0.35
        layer.enabled: true; layer.smooth: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
    }
    // orbit, back half
    Ring {
        x: root.cx - width / 2; y: root.cy - height / 2; width: root.ringW; height: root.ringW
        ratio: root.ratio; half: -1; value: root.progress; color: root.accent; lineWidth: 0.35 * root.u; z: 0
    }
    // moon behind the planet
    Rectangle {
        readonly property real r: root.ringW / 2 - 0.35 * root.u
        width: 3.6 * root.u; height: width; radius: width / 2; color: "white"
        x: root.cx + r * Math.cos(root.ang) - width / 2; y: root.cy + r * root.ratio * Math.sin(root.ang) - height / 2
        z: Math.sin(root.ang) > 0 ? 3 : 0
    }
    Cover {
        x: root.cx - width / 2; y: root.cy - height / 2
        width: 30 * root.u; height: width; radius: width / 2; source: root.cover; z: 1
        RotationAnimator on rotation { from: 0; to: 360; duration: 120000; loops: Animation.Infinite; running: root.playing }
    }
    // orbit, front half
    Ring {
        x: root.cx - width / 2; y: root.cy - height / 2; width: root.ringW; height: root.ringW
        ratio: root.ratio; half: 1; value: root.progress; color: root.accent; lineWidth: 0.35 * root.u; z: 2
    }
    Meta {
        x: root.width / 2 - width / 2; y: root.height * 0.72
        width: 70 * root.u; unit: root.u * 0.9
        title: root.title; artist: root.artist; remainingText: root.remainingText
    }
}
