import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root
    readonly property real horizon: height * 0.6
    property real gridPhase: 0
    NumberAnimation on gridPhase { from: 0; to: 1; duration: 2600; loops: Animation.Infinite; running: root.playing }

    background: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#070707" }
                GradientStop { position: 0.5; color: "#232323" }
                GradientStop { position: 0.6; color: "#7a7a7a" }
                GradientStop { position: 0.6001; color: "#0c0c0c" }
                GradientStop { position: 1.0; color: "#0c0c0c" }
            }
        },
        // sun
        Rectangle {
            width: 62 * root.u; height: width; radius: width / 2
            x: root.width * 0.73 - width / 2; y: root.horizon - height * 0.66
            gradient: Gradient {
                GradientStop { position: 0; color: "#f0f0f0" }
                GradientStop { position: 1; color: "#6a6a6a" }
            }
            Repeater {
                model: 6
                Rectangle {
                    width: parent.width; height: (0.5 + index * 0.55) * root.u
                    y: parent.height * (0.5 + index * 0.075)
                    color: "#3a3a3a"
                }
            }
        },
        // floor
        Rectangle { y: root.horizon; width: root.width; height: root.height - root.horizon; color: "#0c0c0c" },
        Repeater {
            model: 14
            Rectangle {
                readonly property real p: (index + root.gridPhase) / 14
                width: root.width; height: Math.max(1, 0.5 * root.u * p * 2)
                y: root.horizon + (root.height - root.horizon) * Math.pow(p, 2.2)
                color: "#9a9a9a"; opacity: 0.1 + p * 0.6
            }
        },
        Canvas {
            y: root.horizon; width: root.width; height: root.height - root.horizon
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                c.strokeStyle = "rgba(190,190,190,0.42)"
                c.lineWidth = 1.2
                for (var i = -16; i <= 16; i++) {
                    c.beginPath()
                    c.moveTo(width / 2, 0)
                    c.lineTo(width / 2 + i * width / 8, height)
                    c.stroke()
                }
            }
        },
        // dark ramp under the text so it reads over the grid
        Rectangle {
            y: root.horizon - 4 * root.u; width: root.width; height: root.height - y
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#000c0c0c" }
                GradientStop { position: 0.45; color: "#b00c0c0c" }
                GradientStop { position: 1.0; color: "#d90c0c0c" }
            }
        },
        Vignette { strength: 0.5 },
        Grain { }
    ]

    Item {
        x: 14 * root.u + root.driftX; y: 8 * root.u
        width: 74 * root.u; height: width
        Cover { anchors.fill: parent; radius: 1.6 * root.u; source: root.cover; shadow: false }
        Rectangle {
            anchors.fill: parent; anchors.margins: -0.5 * root.u
            color: "transparent"; border.color: "#eeeeee"; border.width: 0.6 * root.u; radius: 2 * root.u
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#ffffff"; shadowBlur: 1.0; shadowOpacity: 0.9; shadowScale: 1.03 }
        }
    }
    TrackInfo {
        x: 102 * root.u; y: 66 * root.u; width: 170 * root.u
        unit: root.u; titleSize: 6.6; showEyebrow: false
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
