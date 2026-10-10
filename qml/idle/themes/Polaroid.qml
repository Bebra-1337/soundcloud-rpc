import QtQuick

// Polaroid: the cover as an instant photo taped to a wall lit from the side, its caption written by hand; beside it
// the title set like a magazine headline in a serif.
ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; veil: root.light ? 0.72 : 0.7; saturation: -0.35; animated: false },
        // light falling on the wall from the upper left
        Glow {
            x: (root.width - 286 * root.u) / 2 - 50 * root.u; y: (root.height - 100 * root.u) / 2 - 80 * root.u
            width: 240 * root.u; height: 220 * root.u
            color: root.light ? "#ffffff" : "#fff3dc"
            strength: root.light ? 0.6 : 0.09
        }
    ]

    Item {
        id: photo
        x: 22 * root.u; y: 9 * root.u
        width: 64 * root.u; height: 80 * root.u
        rotation: -3
        antialiasing: true

        Shadow { anchors.fill: parent; radius: 0.4 * root.u; strength: 0.75; offsetY: 2.2 * root.u }
        // The sheet (paper, photo, caption) is pre-rendered into a 2x texture and only that texture is turned, which
        // keeps the edges smooth.
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.samples: 4
            layer.textureSize: Qt.size(width * 2, height * 2)
            Rectangle {
                anchors.fill: parent; radius: 0.4 * root.u
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f8f6f1" }
                    GradientStop { position: 1; color: "#ebe8e0" }
                }
            }
            Cover {
                x: 3.6 * root.u; y: 3.6 * root.u
                width: parent.width - 7.2 * root.u; height: width
                source: root.cover; shadow: false
            }
            // the photo sits slightly under the paper's surface
            Rectangle {
                x: 3.6 * root.u; y: 3.6 * root.u
                width: parent.width - 7.2 * root.u; height: width
                color: "transparent"; border.color: Qt.rgba(0, 0, 0, 0.12); border.width: 1
            }
            IdleText {
                x: 5 * root.u; y: 64 * root.u; width: parent.width - 10 * root.u
                text: root.title || qsTr("Nothing playing")
                serif: true; font.italic: true
                size: 5.4 * root.u
                color: "#2a2b30"
                elide: Text.ElideRight
            }
            IdleText {
                x: 5 * root.u; y: 70.5 * root.u; width: parent.width - 10 * root.u
                text: root.artist
                serif: true; font.italic: true
                size: 3.8 * root.u
                color: "#5c5d63"
                elide: Text.ElideRight
            }
        }
        // a strip of paper tape
        Rectangle {
            x: parent.width / 2 - 10 * root.u; y: -3.2 * root.u
            width: 20 * root.u; height: 6.4 * root.u
            rotation: 4
            antialiasing: true
            color: Qt.rgba(0.93, 0.91, 0.85, 0.82)
            border.color: Qt.rgba(0, 0, 0, 0.05); border.width: 1
        }
    }

    TrackInfo {
        x: 108 * root.u
        y: (100 * root.u - height) / 2
        width: 164 * root.u
        unit: root.u
        theme: root
        serif: true
        titleWeight: 500
        titleSize: 13.5
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
