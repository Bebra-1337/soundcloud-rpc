import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root
    property real warp: 0
    NumberAnimation on warp { from: 0; to: 1; duration: 6000; loops: Animation.Infinite; running: root.playing }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#000" }
            GradientStop { position: 1; color: "#151515" }
        }
    }
    Repeater {
        model: 160
        Rectangle {
            readonly property real a: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1 * Math.PI * 2
            readonly property real off: Math.abs(Math.sin(index * 78.233) * 12345.678) % 1
            readonly property real p: (root.warp + off) % 1
            readonly property real dist: Math.pow(p, 2.4) * Math.max(root.width, root.height) * 0.75
            x: root.width / 2 + Math.cos(a) * dist; y: root.height / 2 + Math.sin(a) * dist
            width: 0.3 * root.u + p * 1.4 * root.u; height: width; radius: width / 2
            color: index % 5 === 0 ? root.accent : "white"; opacity: Math.min(1, p * 2.5)
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY
        spacing: 4 * root.u
        Item {
            width: 34 * root.u; height: width; anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                anchors.centerIn: parent; width: parent.width * 1.4; height: width; radius: width / 2
                color: root.accent; opacity: 0.3
                layer.enabled: true; layer.smooth: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
            }
            Cover { anchors.fill: parent; radius: width / 2; source: root.cover }
        }
        Meta { width: 70 * root.u; unit: root.u; title: root.title; artist: root.artist; remainingText: root.remainingText }
    }
}
