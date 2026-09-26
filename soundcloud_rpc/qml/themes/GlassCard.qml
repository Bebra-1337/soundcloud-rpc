import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; brightness: -0.3; contrast: 0.15 },
        // drifting light patches give the glass something to refract
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.max(1, root.width / 8), Math.max(1, root.height / 8))
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
            Rectangle {
                width: 80 * root.u; height: width; radius: width / 2; color: "white"; opacity: 0.09
                x: root.width * (0.22 + 0.12 * Math.sin(root.t)) - width / 2
                y: root.height * (0.35 + 0.25 * Math.cos(root.t * 2)) - height / 2
            }
            Rectangle {
                width: 70 * root.u; height: width; radius: width / 2; color: "white"; opacity: 0.07
                x: root.width * (0.8 + 0.1 * Math.cos(root.t * 2)) - width / 2
                y: root.height * (0.7 + 0.2 * Math.sin(root.t)) - height / 2
            }
        },
        Vignette { strength: 0.55 },
        Grain { }
    ]

    Item {
        id: card
        x: 12 * root.u
        y: 12 * root.u
        width: 262 * root.u
        height: 76 * root.u

        Shadow { anchors.fill: parent; radius: 6 * root.u; offsetY: 3 * root.u; strength: 0.55 }
        Rectangle {
            anchors.fill: parent
            radius: 6 * root.u
            border.width: 1
            border.color: "#40ffffff"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#30ffffff" }
                GradientStop { position: 0.5; color: "#16ffffff" }
                GradientStop { position: 1.0; color: "#0affffff" }
            }
        }
        Rectangle {
            x: 8 * root.u; y: 1; width: parent.width - 16 * root.u; height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00ffffff" }
                GradientStop { position: 0.5; color: "#99ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }
        Cover { x: 7 * root.u; y: 7 * root.u; width: 62 * root.u; height: width; radius: 3.2 * root.u; source: root.cover }
        TrackInfo {
            x: 80 * root.u
            y: (card.height - height) / 2
            width: card.width - 80 * root.u - 12 * root.u
            unit: root.u
            title: root.title; artist: root.artist; playing: root.playing
            progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
        }
    }
}
