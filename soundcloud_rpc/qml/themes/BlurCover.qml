import QtQuick

ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; brightness: -0.4; contrast: 0.1; zoom: 1.4 },
        // keeps the secondary text readable over bright covers
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 0.35; color: "#59000000" }
                GradientStop { position: 1.0; color: "#8c000000" }
            }
        },
        Vignette { strength: 0.75; reach: 0.35 },
        Grain { }
    ]

    // faint giant countdown behind everything for depth
    Text {
        x: 279 * root.u - width
        y: -8 * root.u
        text: root.remainingText.replace("-", "")
        color: "#12ffffff"
        font.pixelSize: 64 * root.u
        font.weight: Font.Bold
        font.family: "monospace"
    }

    Cover {
        id: art
        x: 16 * root.u + root.driftX
        y: 8 * root.u + root.driftY
        width: 84 * root.u
        height: width
        radius: 2.6 * root.u
        source: root.cover
        shadowStrength: 0.8
        transform: Rotation {
            origin.x: art.width / 2; origin.y: art.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: -5 + 3 * Math.sin(root.t * 2)
        }
    }
    TrackInfo {
        x: 118 * root.u
        y: (100 * root.u - height) / 2
        width: 153 * root.u
        unit: root.u
        titleSize: 10.6
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
