import QtQuick

// Triptych: the title set right-aligned against the cover, the cover in the middle, the time left on the other side.
// The cover's colors drift behind it all. The cover breathes very slightly while the music plays.
ThemeBase {
    id: root
    readonly property real side: 70 * u

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; veil: root.light ? 0.55 : 0.5; saturation: 0.2 }
    ]

    // The cover is rendered once into a 2x texture and the pulse only scales that texture. Scaling the live cover
    // (image + mask + effects) showed ragged corners; this stays smooth.
    Item {
        id: art
        x: (286 * root.u - root.side) / 2; y: 15 * root.u
        width: root.side; height: width
        Shadow { anchors.fill: parent; radius: 1.6 * root.u; strength: 0.8 }
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            Cover { anchors.fill: parent; radius: 1.6 * root.u; source: root.cover; shadow: false }
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: root.playing
                NumberAnimation { to: 1.012; duration: 3200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 3200; easing.type: Easing.InOutSine }
            }
        }
    }

    TrackInfo {
        x: art.x - 12 * root.u - width
        y: art.y + (art.height - height) / 2
        width: 88 * root.u
        unit: root.u
        align: Text.AlignRight
        titleSize: 8.4
        titleLines: 3
        showProgress: false
        title: root.title; artist: root.artist; playing: root.playing
    }

    Column {
        x: art.x + art.width + 12 * root.u
        width: 72 * root.u
        anchors.verticalCenter: art.verticalCenter
        IdleText {
            //: label above the time left in the track
            text: qsTr("Remaining")
            color: root.alpha(root.ink, 0.6)
            size: 2.4 * root.u
            font.capitalization: Font.AllUppercase
            weight: 600
            tracking: 0.14
        }
        IdleText {
            text: root.remainingText.replace("-", "")
            size: 22 * root.u
            weight: 250
            tracking: -0.03
            tabular: true
            lineHeight: 0.95
        }
        Item { width: 1; height: 3 * root.u }
        Progress {
            width: parent.width; unit: root.u; value: root.progress; playing: root.playing; theme: root
            leftText: root.elapsedText; rightText: root.fmt(root.duration)
        }
        Item { width: 1; height: 1 * root.u }
        Controls { width: parent.width; unit: root.u; theme: root; compact: true }
    }
}
