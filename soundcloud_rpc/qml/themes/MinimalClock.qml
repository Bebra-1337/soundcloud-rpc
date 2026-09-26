import QtQuick

ThemeBase {
    id: root

    Rectangle { anchors.fill: parent; color: "black" }

    Column {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY
        spacing: 2 * root.u
        opacity: root.playing ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: 600 } }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.remainingText
            color: "white"
            font.pixelSize: 34 * root.u; font.weight: Font.Thin; font.family: "monospace"
        }
        Rectangle { width: 60 * root.u; height: 0.4 * root.u; color: root.accent; anchors.horizontalCenter: parent.horizontalCenter
            Rectangle { width: parent.width * root.progress; height: parent.height; color: "white" } }
        Text {
            width: 80 * root.u; horizontalAlignment: Text.AlignHCenter
            text: root.title; color: "#ddd"; elide: Text.ElideRight
            font.pixelSize: 4 * root.u; font.weight: Font.Medium
        }
        Text {
            width: 80 * root.u; horizontalAlignment: Text.AlignHCenter
            text: root.artist; color: "#777"; elide: Text.ElideRight
            font.pixelSize: 3 * root.u
        }
    }
    Cover {
        x: 4 * root.u; y: root.height - height - 4 * root.u
        width: 11 * root.u; height: width; radius: 0.8 * root.u; source: root.cover; shadow: false
        opacity: 0.85
    }
}
