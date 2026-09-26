import QtQuick

ThemeBase {
    id: root
    readonly property bool wide: width >= height * 1.1

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#1c1c1c" }
            GradientStop { position: 1; color: "#0a0a0a" }
        }
    }

    Item {
        id: rec
        width: (root.wide ? 78 : 66) * root.u; height: width
        x: (root.wide ? root.width * 0.30 : root.width / 2) - width / 2 + root.driftX
        y: (root.wide ? root.height / 2 - height / 2 : root.height * 0.06 + 4 * root.u) + root.driftY

        Ring {
            anchors.centerIn: parent
            width: parent.width + 7 * root.u; height: width
            value: root.progress; color: root.accent; lineWidth: 0.7 * root.u
        }
        Item {
            id: disc
            anchors.fill: parent
            RotationAnimator on rotation {
                from: 0; to: 360; duration: 5000; loops: Animation.Infinite; running: root.playing
            }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#0c0c0c"; border.color: "#2a2a2a"; border.width: 2 }
            Repeater {
                model: 16
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (0.97 - index * 0.026); height: width; radius: width / 2
                    color: "transparent"
                    border.color: index % 3 === 0 ? "#222" : "#161616"
                    border.width: 1
                }
            }
            Cover {
                anchors.centerIn: parent
                width: parent.width * 0.36; height: width; radius: width / 2
                source: root.cover; shadow: false
            }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.035; height: width; radius: width / 2; color: "#0c0c0c" }
        }
        // static sheen so the spin is visible
        Rectangle {
            anchors.fill: parent; radius: width / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00ffffff" }
                GradientStop { position: 0.35; color: "#0dffffff" }
                GradientStop { position: 0.5; color: "#00ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }
    }

    // Tonearm: swings onto the record and drifts inward with progress
    Item {
        id: arm
        x: rec.x + rec.width + 1 * root.u; y: rec.y + 5 * root.u
        width: 2.4 * root.u; height: 50 * root.u
        transformOrigin: Item.Top
        rotation: root.playing ? -22 - root.progress * 12 : -3
        Behavior on rotation { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
        Rectangle { anchors.fill: parent; radius: width / 2; color: "#c8c8c8" }
        Rectangle { x: -1.2 * root.u; y: parent.height - 3 * root.u; width: 4.8 * root.u; height: 8 * root.u; radius: 0.6 * root.u; color: "#8a8a8a" }
        Rectangle { x: -1.6 * root.u; y: -2 * root.u; width: 5.6 * root.u; height: 5.6 * root.u; radius: width / 2; color: "#555" }
    }

    Meta {
        x: root.wide ? root.width * 0.55 : root.width * 0.1
        width: root.wide ? root.width * 0.38 : root.width * 0.8
        y: root.wide ? root.height / 2 - height / 2 : rec.y + rec.height + 9 * root.u
        align: root.wide ? Text.AlignLeft : Text.AlignHCenter
        unit: root.u
        title: root.title; artist: root.artist; remainingText: root.remainingText
    }
}
