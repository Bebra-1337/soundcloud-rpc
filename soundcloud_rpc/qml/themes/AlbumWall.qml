import QtQuick

ThemeBase {
    id: root
    readonly property real tile: 20 * u
    readonly property real pitch: tile + 2 * u

    Rectangle { anchors.fill: parent; color: "#0d0d0d" }

    Item {
        width: root.width * 1.7; height: root.height * 1.7
        anchors.centerIn: parent
        rotation: -12
        Column {
            spacing: root.u * 2
            Repeater {
                model: 9
                Row {
                    id: wallRow
                    spacing: root.u * 2
                    x: (index % 2 ? -1 : 1) * root.pitch * (root.t / (Math.PI * 2)) - root.pitch * (index % 2 ? 0.5 : 1.5) - (index % 2 ? 0 : 0)
                    Repeater {
                        model: 16
                        Image {
                            width: root.tile; height: root.tile
                            source: root.cover; sourceSize.width: 200; sourceSize.height: 200
                            fillMode: Image.PreserveAspectCrop; asynchronous: true
                            opacity: 0.35
                        }
                    }
                }
            }
        }
    }
    Rectangle { anchors.fill: parent; color: "#66000000" }

    Column {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY
        spacing: 3 * root.u
        Cover { width: 40 * root.u; height: width; radius: 1 * root.u; source: root.cover; anchors.horizontalCenter: parent.horizontalCenter }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 70 * root.u; height: childrenRect.height + 3 * root.u; radius: 1.5 * root.u; color: "#99000000"
            Meta {
                anchors.centerIn: parent; width: parent.width - 4 * root.u; unit: root.u * 0.9
                title: root.title; artist: root.artist; remainingText: root.remainingText
            }
        }
    }
}
