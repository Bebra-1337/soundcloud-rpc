import QtQuick

ThemeBase {
    id: root

    background: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#262626" }
                GradientStop { position: 1; color: "#0f0f0f" }
            }
        },
        Vignette { strength: 0.6 },
        Grain { amount: 0.1 }
    ]

    Item {
        id: tape
        x: 9 * root.u + root.driftX
        y: 3 * root.u + root.driftY
        width: 152 * root.u
        height: 94 * root.u

        Shadow { anchors.fill: parent; radius: 4 * root.u; offsetY: 2 * root.u; strength: 0.7 }
        Rectangle {
            anchors.fill: parent; radius: 4 * root.u
            border.color: "#464646"; border.width: 1
            gradient: Gradient {
                GradientStop { position: 0; color: "#2e2e2e" }
                GradientStop { position: 1; color: "#1c1c1c" }
            }
        }
        Repeater {
            model: 4
            Rectangle {
                width: 2.6 * root.u; height: width; radius: width / 2; color: "#5a5a5a"; border.color: "#2a2a2a"
                x: (index % 2 ? tape.width - 5.2 * root.u : 2.6 * root.u)
                y: (index < 2 ? 2.6 * root.u : tape.height - 5.2 * root.u)
            }
        }
        // paper label
        Rectangle {
            id: label
            x: 10 * root.u; y: 8 * root.u
            width: tape.width - 20 * root.u; height: 48 * root.u
            radius: 1.6 * root.u; color: "#dcdcdc"
            Rectangle {
                width: parent.width; height: 9 * root.u; radius: 1.6 * root.u; color: "#161616"
                Text { x: 3 * root.u; anchors.verticalCenter: parent.verticalCenter; text: "SIDE A"; color: "#dcdcdc"; font.pixelSize: 3.4 * root.u; font.weight: Font.Bold; font.letterSpacing: 0.4 * root.u }
                Text { x: parent.width - width - 3 * root.u; anchors.verticalCenter: parent.verticalCenter; text: "C-60  ·  HIGH BIAS"; color: "#8a8a8a"; font.pixelSize: 2.6 * root.u; font.letterSpacing: 0.3 * root.u }
            }
            Text {
                x: 5 * root.u; y: 11.5 * root.u; width: label.width - 46 * root.u
                text: root.title || "Nothing playing"
                color: "#141414"; font.pixelSize: 7.4 * root.u; font.italic: true; font.weight: Font.Bold
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 0.92
            }
            Text {
                x: 5 * root.u; y: 35 * root.u; width: label.width - 46 * root.u
                text: root.artist; color: "#555555"; font.pixelSize: 4.2 * root.u; font.italic: true; elide: Text.ElideRight
            }
            Repeater {
                model: 2
                Rectangle { x: 5 * root.u; y: (32 + index * 8.5) * root.u; width: label.width - 46 * root.u; height: 1; color: "#a8a8a8"; visible: index === 1 }
            }
            Cover {
                x: label.width - 33 * root.u; y: 12 * root.u; width: 28 * root.u; height: width
                radius: 1 * root.u; source: root.cover; shadow: false
            }
        }
        // tape window with reels
        Rectangle {
            id: win
            x: 30 * root.u; y: 61 * root.u; width: 92 * root.u; height: 24 * root.u
            radius: 12 * root.u; color: "#0b0b0b"; border.color: "#4a4a4a"; border.width: 2
            Repeater {
                model: 2
                Item {
                    readonly property real amount: index === 0 ? 1 - root.progress : root.progress
                    width: win.height - 3 * root.u; height: width
                    x: index === 0 ? 1.5 * root.u : win.width - width - 1.5 * root.u
                    y: 1.5 * root.u
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * (0.56 + 0.44 * amount); height: width; radius: width / 2
                        color: "#2e2e2e"; border.color: "#3a3a3a"
                    }
                    Item {
                        anchors.fill: parent
                        RotationAnimator on rotation { from: 0; to: -360; duration: 3600; loops: Animation.Infinite; running: root.playing }
                        Rectangle { anchors.centerIn: parent; width: parent.width * 0.52; height: width; radius: width / 2; color: "#e4e4e4" }
                        Repeater {
                            model: 6
                            Rectangle { anchors.centerIn: parent; width: parent.width * 0.52; height: root.u * 0.8; color: "#1e1e1e"; rotation: index * 30 }
                        }
                        Rectangle { anchors.centerIn: parent; width: parent.width * 0.2; height: width; radius: width / 2; color: "#1e1e1e" }
                    }
                }
            }
        }
    }

    // digital counter and progress on the right
    Column {
        x: 180 * root.u; width: 98 * root.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1.2 * root.u
        NowPlaying { width: parent.width; unit: root.u; playing: root.playing }
        Text { text: "COUNTER"; color: root.inkFaint; font.pixelSize: 2.3 * root.u; font.letterSpacing: 0.45 * root.u }
        Rectangle {
            width: parent.width; height: 24 * root.u; radius: 1.6 * root.u; color: "#0a0a0a"; border.color: "#333"
            Text {
                anchors.centerIn: parent
                text: root.remainingText
                color: "#e8e8e8"; font.pixelSize: 15 * root.u; font.family: "monospace"; font.weight: Font.Bold
            }
        }
        Item { width: 1; height: 1.5 * root.u }
        Progress { width: parent.width; unit: root.u; value: root.progress; leftText: root.elapsedText; rightText: "" }
    }
}
