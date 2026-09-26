import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root
    readonly property real horizon: height * 0.6

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0a0a0a" }
            GradientStop { position: 0.45; color: "#2a2a2a" }
            GradientStop { position: 0.6; color: "#cccccc" }
            GradientStop { position: 0.6001; color: "#111111" }
            GradientStop { position: 1.0; color: "#111111" }
        }
    }
    // sun
    Rectangle {
        width: 48 * root.u; height: width; radius: width / 2
        x: root.width / 2 - width / 2; y: root.horizon - height * 0.62
        gradient: Gradient {
            GradientStop { position: 0; color: "#bbbbbb" }
            GradientStop { position: 1; color: "#555555" }
        }
        Repeater {
            model: 6
            Rectangle {
                width: parent.width; height: (0.5 + index * 0.5) * root.u
                y: parent.height * (0.55 + index * 0.07)
                color: "#2a2a2a"; opacity: 0.9
            }
        }
    }
    // floor
    Rectangle { x: 0; y: root.horizon; width: root.width; height: root.height - root.horizon; color: "#111111" }
    Repeater {
        model: 14
        Rectangle {
            readonly property real p: ((index + gridPhase) / 14)
            property real gridPhase: 0
            width: root.width; height: Math.max(1, 0.35 * root.u * p * 2)
            y: root.horizon + (root.height - root.horizon) * Math.pow(p, 2.2)
            color: root.accent2; opacity: 0.25 + p * 0.75
            NumberAnimation on gridPhase { from: 0; to: 1; duration: 2500; loops: Animation.Infinite; running: root.playing }
        }
    }
    Canvas {
        x: 0; y: root.horizon; width: root.width; height: root.height - root.horizon
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext("2d")
            c.reset()
            c.strokeStyle = "rgba(170,170,170,0.5)"
            c.lineWidth = 1.5
            for (var i = -14; i <= 14; i++) {
                c.beginPath()
                c.moveTo(width / 2, 0)
                c.lineTo(width / 2 + i * width / 7, height)
                c.stroke()
            }
        }
    }

    // framed cover with neon glow
    Item {
        width: 30 * root.u; height: width
        x: root.width / 2 - width / 2 + root.driftX; y: root.height * 0.08 + root.driftY
        Cover { anchors.fill: parent; radius: 0.8 * root.u; source: root.cover; shadow: false }
        Rectangle {
            anchors.fill: parent; anchors.margins: -0.5 * root.u
            color: "transparent"; border.color: "#cccccc"; border.width: 0.7 * root.u; radius: 1 * root.u
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#cccccc"; shadowBlur: 1.0; shadowOpacity: 1.0; shadowScale: 1.05 }
        }
    }
    Meta {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.78
        width: 80 * root.u; unit: root.u * 0.85
        title: root.title; artist: root.artist; remainingText: root.remainingText
        color: "#dddddd"
    }
}
