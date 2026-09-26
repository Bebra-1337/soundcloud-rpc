import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root

    Rectangle { anchors.fill: parent; color: "#111111" }
    Item {
        anchors.fill: parent
        layer.enabled: true; layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, root.width / 8), Math.max(1, root.height / 8))
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.5 }
        Repeater {
            model: [root.accent, root.accent2, Qt.lighter(root.accent2, 1.5)]
            Rectangle {
                width: 60 * root.u; height: width; radius: width / 2; color: modelData; opacity: 0.9
                x: root.width * (0.5 + 0.4 * Math.sin(root.t * (index + 1) + index * 2)) - width / 2
                y: root.height * (0.5 + 0.4 * Math.cos(root.t * (3 - index) + index)) - height / 2
            }
        }
    }

    Rectangle {
        id: card
        width: 88 * root.u; height: 40 * root.u; radius: 4 * root.u
        x: root.width / 2 - width / 2 + 3 * root.u * Math.sin(root.t * 2)
        y: root.height / 2 - height / 2 + 2 * root.u * Math.cos(root.t * 3)
        color: "#26ffffff"; border.color: "#55ffffff"; border.width: 1.5
        Row {
            anchors.fill: parent; anchors.margins: 4 * root.u; spacing: 4 * root.u
            Cover { width: parent.height; height: width; radius: 2 * root.u; source: root.cover }
            Column {
                width: parent.width - parent.height - 4 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1.5 * root.u
                Meta {
                    width: parent.width; unit: root.u * 0.85; align: Text.AlignLeft
                    title: root.title; artist: root.artist; remainingText: root.remainingText; showRemaining: false
                }
                Bar { width: parent.width; height: 0.8 * root.u; value: root.progress; color: "white" }
                Text { text: root.remainingText; color: "white"; opacity: 0.85; font.pixelSize: 3 * root.u; font.family: "monospace" }
            }
        }
    }
}
