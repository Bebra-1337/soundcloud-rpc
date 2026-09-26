import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root
    readonly property real armAngle: root.playing ? 26 + root.progress * 12 : 4

    background: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#1c1c1c" }
                GradientStop { position: 1; color: "#0a0a0a" }
            }
        },
        // spotlight behind the turntable
        Rectangle {
            x: root.width * 0.21 - width / 2; y: root.height / 2 - height / 2
            width: 120 * root.u; height: width; radius: width / 2; color: "white"; opacity: 0.07
            layer.enabled: true; layer.smooth: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
        },
        Vignette { strength: 0.6 },
        Grain { }
    ]

    Item {
        id: rec
        x: 10 * root.u + root.driftX
        y: 4 * root.u + root.driftY
        width: 92 * root.u
        height: width

        Shadow { anchors.fill: parent; radius: width / 2; offsetY: 2 * root.u; strength: 0.7 }
        Rectangle { anchors.fill: parent; radius: width / 2; color: "#0d0d0d"; border.color: "#2b2b2b"; border.width: 2 }
        Repeater {
            model: 24
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (0.965 - index * 0.0245); height: width; radius: width / 2
                color: "transparent"
                border.color: index % 4 === 0 ? "#242424" : "#171717"
                border.width: 1
            }
        }
        // light sweeps that rotate with the disc
        Canvas {
            id: sheen
            anchors.fill: parent
            RotationAnimator on rotation { from: 0; to: 360; duration: 5400; loops: Animation.Infinite; running: root.playing }
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                var g = c.createConicalGradient(width / 2, height / 2, 0)
                g.addColorStop(0.00, "rgba(255,255,255,0)")
                g.addColorStop(0.05, "rgba(255,255,255,0.13)")
                g.addColorStop(0.11, "rgba(255,255,255,0)")
                g.addColorStop(0.50, "rgba(255,255,255,0)")
                g.addColorStop(0.55, "rgba(255,255,255,0.13)")
                g.addColorStop(0.61, "rgba(255,255,255,0)")
                g.addColorStop(1.00, "rgba(255,255,255,0)")
                c.fillStyle = g
                c.beginPath()
                c.arc(width / 2, height / 2, width / 2 - 3, 0, Math.PI * 2)
                c.fill()
            }
        }
        Cover {
            anchors.centerIn: parent
            width: parent.width * 0.36; height: width; radius: width / 2
            source: root.cover; shadow: false
        }
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.03; height: width; radius: width / 2; color: "#0d0d0d"; border.color: "#333"; border.width: 1 }
        Ring {
            anchors.centerIn: parent
            width: parent.width + 6 * root.u; height: width
            value: root.progress; color: root.ink; lineWidth: 0.35 * root.u; trackColor: "#1fffffff"
        }
    }

    // tonearm: pivot at the top right of the record, swings onto the groove and creeps inward
    Item {
        x: 116 * root.u + root.driftX; y: 12 * root.u
        Rectangle { x: -4.5 * root.u; y: -4.5 * root.u; width: 9 * root.u; height: width; radius: width / 2; color: "#2a2a2a"; border.color: "#4a4a4a"; border.width: 2 }
        Item {
            id: arm
            width: 1.8 * root.u; height: 62 * root.u
            x: -width / 2
            transformOrigin: Item.Top
            rotation: root.armAngle
            Behavior on rotation { NumberAnimation { duration: 1100; easing.type: Easing.InOutQuad } }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#bdbdbd" }
            Rectangle { x: -1.6 * root.u; y: parent.height - 2 * root.u; width: 5 * root.u; height: 9 * root.u; radius: 0.8 * root.u; color: "#8a8a8a" }
        }
        Rectangle { x: -2.5 * root.u; y: -2.5 * root.u; width: 5 * root.u; height: width; radius: width / 2; color: "#6a6a6a" }
    }

    TrackInfo {
        x: 132 * root.u
        y: (100 * root.u - height) / 2
        width: 141 * root.u
        unit: root.u
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
