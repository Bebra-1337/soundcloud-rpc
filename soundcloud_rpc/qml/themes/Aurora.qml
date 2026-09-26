import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root

    background: [
        Rectangle { anchors.fill: parent; color: "#0e0e0e" },
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.max(1, root.width / 8), Math.max(1, root.height / 8))
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
            Repeater {
                model: ["#e6e6e6", "#8a8a8a", "#bdbdbd", "#5a5a5a", "#d0d0d0"]
                Rectangle {
                    readonly property int kx: [1, 2, 1, 3, 2][index]
                    readonly property int ky: [2, 1, 3, 1, 2][index]
                    width: (55 + index * 8) * root.u; height: width * 0.7; radius: height / 2
                    color: modelData
                    opacity: 0.32
                    rotation: index * 37 + root.t * 57.3 * 0
                    x: root.width * (0.5 + 0.42 * Math.sin(root.t * kx + index * 1.7)) - width / 2
                    y: root.height * (0.5 + 0.38 * Math.cos(root.t * ky + index * 2.3)) - height / 2
                }
            }
        },
        Vignette { strength: 0.6 },
        Grain { }
    ]

    // symmetric composition: title left, cover center, countdown right
    // The cover is rendered once into a 2x texture and the pulse only scales that texture. Scaling the live
    // cover (image + mask + effects) showed ragged top corners; this stays smooth.
    Item {
        id: art
        x: (286 - 76) / 2 * root.u
        y: 12 * root.u
        width: 76 * root.u
        height: width
        Shadow { anchors.fill: parent; radius: 3 * root.u; offsetY: 0.06 * height; strength: 0.6 }
        Item {
            id: pulse
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            Cover { anchors.fill: parent; radius: 3 * root.u; source: root.cover; shadow: false }
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: root.playing
                NumberAnimation { to: 1.025; duration: 2200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 2200; easing.type: Easing.InOutSine }
            }
        }
    }
    Column {
        x: 8 * root.u; width: 80 * root.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1.4 * root.u
        NowPlaying { width: parent.width; unit: root.u; playing: root.playing; align: Text.AlignRight }
        Text {
            width: parent.width; text: root.title || "Nothing playing"; color: root.ink
            horizontalAlignment: Text.AlignRight; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
            font.pixelSize: 7.6 * root.u; font.weight: Font.DemiBold; lineHeight: 0.95; font.letterSpacing: -0.9
        }
        Text {
            width: parent.width; text: root.artist; color: root.inkDim; visible: text !== ""
            horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; font.pixelSize: 4.4 * root.u
        }
    }
    Column {
        x: 198 * root.u; width: 80 * root.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0.5 * root.u
        Text {
            text: "REMAINING"; color: root.inkDim
            font.pixelSize: 2.3 * root.u; font.letterSpacing: 0.45 * root.u; font.weight: Font.Medium
        }
        Text {
            text: root.remainingText.replace("-", "")
            color: root.ink; font.pixelSize: 21 * root.u; font.family: "monospace"; font.weight: Font.Light
        }
        Item { width: 1; height: 1 * root.u }
        Progress { width: parent.width; unit: root.u; value: root.progress; leftText: root.elapsedText; rightText: ""; labels: true }
    }
}
