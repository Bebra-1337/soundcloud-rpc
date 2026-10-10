import QtQuick

// A slab of liquid glass over the cover: the cover and the track sit on it like a card on a desk. The slab's middle
// is frosted and tinted with the background color so the text reads; its rim stays clear and bends the cover's
// shapes behind it, splitting their edges into a faint spectrum. The buttons are small lenses of the same glass,
// refracting the slab and the cover under them.
ThemeBase {
    id: root

    // the stage's origin in the backdrop (ThemeBase centers the stage on whole pixels)
    readonly property real stageX: Math.round((width - 286 * u) / 2)
    readonly property real stageY: Math.round((height - 100 * u) / 2)

    background: [
        Item {
            id: scene
            anchors.fill: parent
            Item {
                id: wall
                anchors.fill: parent
                // the cover itself, large and only softly blurred, so its shapes are there for the glass to bend
                BlurBackdrop {
                    anchors.fill: parent; source: root.cover
                    detail: 96; blurMax: 3; copies: 1
                    veil: root.light ? 0.22 : 0.18; saturation: 0.15
                }
            }
            // the slab lives in the backdrop, so the buttons' lenses can refract it
            LiquidGlass {
                x: root.stageX + card.x; y: root.stageY + card.y
                width: card.width; height: card.height
                source: wallSource
                radius: 5 * root.u
                bezel: 5 * root.u
                thickness: 6 * root.u
                frost: 1; clearRim: 1
                tint: root.alpha(root.bg, root.light ? 0.22 : 0.2)
                saturation: 1.2
                brightness: root.light ? 1.04 : 0.92
                rimLight: root.light ? 1.0 : 0.8
                shadowOpacity: root.light ? 0.1 : 0.24
                shadowRadius: 5 * root.u
                shadowOffset: 1.4 * root.u
            }
        }
    ]

    // the backdrop drifts slowly: 30 captures a second are enough for the glass
    GlassSource { id: wallSource; sourceItem: wall; blurEnabled: true; blurRadius: 48; fps: 30 }
    GlassSource { id: sceneSource; sourceItem: scene; fps: 30 }

    Item {
        id: card
        x: 11 * root.u; y: 11 * root.u
        width: 264 * root.u; height: 78 * root.u

        Cover {
            x: 8 * root.u; y: 8 * root.u
            width: 62 * root.u; height: width
            radius: 2.2 * root.u
            source: root.cover
            shadowStrength: 0.5
        }
        TrackInfo {
            x: 82 * root.u
            y: (card.height - height) / 2 + 0.6 * root.u
            width: card.width - 82 * root.u - 12 * root.u
            unit: root.u
            theme: root
            glass: true
            glassSource: sceneSource
            titleSize: 9
            title: root.title; artist: root.artist; playing: root.playing
            progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
        }
    }
}
