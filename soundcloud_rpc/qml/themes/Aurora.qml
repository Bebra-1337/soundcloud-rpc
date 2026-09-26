import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root

    Rectangle { anchors.fill: parent; color: "#111111" }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, root.width / 8), Math.max(1, root.height / 8))
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.3 }

        Repeater {
            model: [root.accent, root.accent2, Qt.lighter(root.accent, 1.4), Qt.darker(root.accent2, 1.2)]
            Rectangle {
                readonly property int kx: [1, 2, 1, 3][index]
                readonly property int ky: [2, 1, 3, 1][index]
                width: 75 * root.u; height: width; radius: width / 2
                color: modelData
                opacity: 0.85
                x: root.width * (0.5 + 0.38 * Math.sin(root.t * kx + index * 1.7)) - width / 2
                y: root.height * (0.5 + 0.38 * Math.cos(root.t * ky + index * 2.3)) - height / 2
            }
        }
    }
    Rectangle { anchors.fill: parent; color: "#33000000" }

    Column {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY
        spacing: 4 * root.u
        Cover {
            width: 42 * root.u; height: width; radius: 2 * root.u; source: root.cover
            anchors.horizontalCenter: parent.horizontalCenter
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: root.playing
                NumberAnimation { to: 1.03; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
            }
        }
        Meta { width: 70 * root.u; unit: root.u; title: root.title; artist: root.artist; remainingText: root.remainingText }
    }
}
