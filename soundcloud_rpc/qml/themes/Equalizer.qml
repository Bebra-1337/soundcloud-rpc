import QtQuick

ThemeBase {
    id: root

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#161616" }
            GradientStop { position: 1; color: "#000" }
        }
    }

    // fast phase for the fake spectrum
    property real ph: 0
    NumberAnimation on ph { from: 0; to: Math.PI * 2 * 8; duration: 24000; loops: Animation.Infinite; running: root.playing }

    Row {
        id: bars
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4 * root.u
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0.6 * root.u
        Repeater {
            model: 56
            Rectangle {
                readonly property real v: root.playing
                    ? Math.abs(Math.sin(root.ph * (1 + index % 3) + index * 0.55) * Math.cos(root.ph * 2 + index * 0.31))
                      * (1 - Math.abs(index - 27.5) / 45) : 0
                width: (root.width - 6 * root.u - 55 * 0.6 * root.u) / 56
                height: Math.max(0.6 * root.u, v * 34 * root.u)
                anchors.bottom: parent.bottom
                radius: width / 2
                Behavior on height { NumberAnimation { duration: 140 } }
                gradient: Gradient {
                    GradientStop { position: 0; color: root.accent }
                    GradientStop { position: 1; color: root.accent2 }
                }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.07 + root.driftY
        spacing: 3 * root.u
        Cover { width: 36 * root.u; height: width; radius: 1.5 * root.u; source: root.cover; anchors.horizontalCenter: parent.horizontalCenter }
        Meta { width: 70 * root.u; unit: root.u * 0.9; title: root.title; artist: root.artist; remainingText: root.remainingText }
    }
}
