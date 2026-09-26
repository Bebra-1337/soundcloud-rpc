import QtQuick

ThemeBase {
    id: root
    readonly property real tile: 34 * u
    readonly property real gap: 1.6 * u
    readonly property real pitch: tile + gap

    background: [
        Rectangle { anchors.fill: parent; color: "#0d0d0d" },
        Item {
            width: root.width * 1.5; height: root.height * 2.2
            x: -root.width * 0.25; y: -root.height * 0.6
            rotation: -9
            Column {
                spacing: root.gap
                Repeater {
                    model: 7
                    Row {
                        spacing: root.gap
                        x: (index % 2 ? -1 : 1) * root.pitch * (root.t / (Math.PI * 2)) - root.pitch * 1.5
                        Repeater {
                            model: 12
                            Image {
                                width: root.tile; height: root.tile
                                source: root.cover; sourceSize.width: 200; sourceSize.height: 200
                                fillMode: Image.PreserveAspectCrop; asynchronous: true
                                opacity: 0.55
                            }
                        }
                    }
                }
            }
        },
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#40111111" }
                GradientStop { position: 0.42; color: "#b3111111" }
                GradientStop { position: 1.0; color: "#f0111111" }
            }
        },
        Vignette { strength: 0.5 },
        Grain { }
    ]

    Cover {
        x: 16 * root.u + root.driftX; y: 8 * root.u + root.driftY
        width: 84 * root.u; height: width; radius: 2.6 * root.u; source: root.cover; shadowStrength: 0.85
    }
    TrackInfo {
        x: 118 * root.u
        y: (100 * root.u - height) / 2
        width: 153 * root.u
        unit: root.u; titleSize: 9.6
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
