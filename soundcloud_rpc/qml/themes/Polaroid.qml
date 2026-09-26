import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; brightness: -0.55; contrast: -0.1 },
        // spotlight on the wall behind the photo
        Rectangle {
            x: root.width * 0.2 - width / 2; y: root.height / 2 - height / 2
            width: 110 * root.u; height: width; radius: width / 2; color: "white"; opacity: 0.16
            layer.enabled: true; layer.smooth: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
        },
        Vignette { strength: 0.75 },
        Grain { amount: 0.14 }
    ]

    Item {
        id: photo
        x: 24 * root.u + root.driftX; y: 8 * root.u + root.driftY
        width: 66 * root.u; height: 84 * root.u
        transformOrigin: Item.Top
        rotation: -4
        SequentialAnimation on rotation {
            loops: Animation.Infinite
            NumberAnimation { to: 2.5; duration: 8000; easing.type: Easing.InOutSine }
            NumberAnimation { to: -4; duration: 8000; easing.type: Easing.InOutSine }
        }
        Shadow { anchors.fill: parent; radius: 0.6 * root.u; offsetY: 2 * root.u; strength: 0.7 }
        Rectangle { anchors.fill: parent; color: "#e4e2dd"; radius: 0.6 * root.u }
        Cover { x: 4 * root.u; y: 4 * root.u; width: parent.width - 8 * root.u; height: width; source: root.cover; shadow: false }
        Text {
            x: 5 * root.u; y: 66 * root.u; width: parent.width - 10 * root.u
            text: root.title || "Nothing playing"; color: "#202020"; elide: Text.ElideRight
            font.pixelSize: 4.6 * root.u; font.italic: true; font.family: "serif"; font.weight: Font.DemiBold
        }
        Text {
            x: 5 * root.u; y: 73.5 * root.u; width: parent.width - 10 * root.u
            text: root.artist; color: "#6a6a6a"; elide: Text.ElideRight
            font.pixelSize: 3.4 * root.u; font.italic: true; font.family: "serif"
        }
        // masking tape
        Rectangle {
            x: parent.width / 2 - 11 * root.u; y: -3 * root.u; width: 22 * root.u; height: 7 * root.u
            color: "#a8d4d4d4"; rotation: 3
        }
    }

    Column {
        x: 112 * root.u; width: 161 * root.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1.6 * root.u
        NowPlaying { width: parent.width; unit: root.u; playing: root.playing }
        Text {
            width: parent.width; text: root.title || "Nothing playing"; color: root.ink
            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 0.95
            font.pixelSize: 10.5 * root.u; font.italic: true; font.family: "serif"; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width; text: root.artist.toUpperCase(); color: root.inkDim; visible: text !== ""
            elide: Text.ElideRight; font.pixelSize: 3.6 * root.u; font.letterSpacing: 0.9 * root.u
        }
        Item { width: 1; height: 1.4 * root.u }
        Progress { width: parent.width; unit: root.u; value: root.progress; leftText: root.elapsedText; rightText: root.remainingText }
    }
}
