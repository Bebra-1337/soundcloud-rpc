import QtQuick

ThemeBase {
    id: root

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#2a2a2a" }
            GradientStop { position: 1; color: "#141414" }
        }
    }

    Item {
        id: tape
        width: 96 * root.u; height: 62 * root.u
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY

        Rectangle { anchors.fill: parent; radius: 3 * root.u; color: "#1e1e1e"; border.color: "#3c3c3c"; border.width: 2 }
        // screws
        Repeater {
            model: 4
            Rectangle {
                width: 2.4 * root.u; height: width; radius: width / 2; color: "#636363"
                x: (index % 2 ? tape.width - 5 * root.u : 2.6 * root.u)
                y: (index < 2 ? 2.6 * root.u : tape.height - 5 * root.u)
            }
        }
        // label
        Rectangle {
            x: 6 * root.u; y: 5 * root.u; width: tape.width - 12 * root.u; height: 27 * root.u
            radius: 1.2 * root.u; color: "#cfcfcf"
            Rectangle { anchors.top: parent.top; width: parent.width; height: 5 * root.u; radius: 1.2 * root.u; color: root.accent }
            Text {
                x: 3 * root.u; y: 6.5 * root.u; width: parent.width - 6 * root.u
                text: root.title || "Nothing playing"
                font.pixelSize: 4.4 * root.u; font.italic: true; font.weight: Font.Bold
                color: "#111111"; elide: Text.ElideRight
            }
            Text {
                x: 3 * root.u; y: 14 * root.u; width: parent.width - 6 * root.u
                text: root.artist
                font.pixelSize: 3.2 * root.u; font.italic: true
                color: "#555555"; elide: Text.ElideRight
            }
            Repeater {
                model: 2
                Rectangle { x: 3 * root.u; y: (19 + index * 3.2) * root.u; width: parent.width - 6 * root.u; height: 1; color: "#a0a0a0" }
            }
        }
        // window with reels
        Rectangle {
            id: win
            x: 14 * root.u; y: 34 * root.u; width: tape.width - 28 * root.u; height: 17 * root.u
            radius: 8.5 * root.u; color: "#0d0d0d"; border.color: "#555"; border.width: 2
            Repeater {
                model: 2
                Item {
                    readonly property real amount: index === 0 ? 1 - root.progress : root.progress
                    width: win.height - 2 * root.u; height: width
                    x: index === 0 ? 1.2 * root.u : win.width - width - 1.2 * root.u
                    y: 1 * root.u
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * (0.5 + 0.5 * amount); height: width; radius: width / 2
                        color: "#2e2e2e"
                    }
                    Item {
                        anchors.fill: parent
                        RotationAnimator on rotation { from: 0; to: -360; duration: 3500; loops: Animation.Infinite; running: root.playing }
                        Rectangle { anchors.centerIn: parent; width: parent.width * 0.5; height: width; radius: width / 2; color: "#e8e8e8" }
                        Repeater {
                            model: 6
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.5; height: root.u * 0.7; color: "#1e1e1e"
                                rotation: index * 60
                            }
                        }
                        Rectangle { anchors.centerIn: parent; width: parent.width * 0.2; height: width; radius: width / 2; color: "#1e1e1e" }
                    }
                }
            }
        }
        // counter
        Rectangle {
            x: tape.width / 2 - 13 * root.u; y: tape.height - 8 * root.u; width: 26 * root.u; height: 5.5 * root.u
            radius: 0.8 * root.u; color: "#0a0a0a"
            Text {
                anchors.centerIn: parent
                text: root.remainingText
                color: "#cccccc"; font.family: "monospace"; font.pixelSize: 3.8 * root.u; font.weight: Font.Bold
            }
        }
    }
}
