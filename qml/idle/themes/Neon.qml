import QtQuick

// Horizon: dusk over still water. A low sun in the accent, its reflection broken into slow shimmering lines on the
// water below, the sky taking a little of the cover's colors. The cover and the track sit over it in the foreground.
ThemeBase {
    id: root
    readonly property real sy: Math.round((height - 100 * u) / 2)
    readonly property real horizon: sy + 64 * u
    readonly property real sunX: (width - 286 * u) / 2 + 222 * u
    readonly property real sunR: 17 * u
    readonly property color skyLow: light ? mix(bg, accent, 0.28) : mix(mix(bg, "#000000", 0.3), accent, 0.3)
    readonly property color skyHigh: light ? mix(bg, "#ffffff", 0.5) : mix(bg, "#000000", 0.45)
    readonly property color water: light ? mix(bg, accent, 0.07) : mix(bg, "#000000", 0.55)

    background: [
        // sky
        Rectangle {
            width: root.width; height: root.horizon
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.skyHigh }
                GradientStop { position: 0.65; color: root.mix(root.skyHigh, root.skyLow, 0.55) }
                GradientStop { position: 1.0; color: root.skyLow }
            }
        },
        // the cover's colors in the upper sky, faintly
        Item {
            width: root.width; height: root.horizon
            clip: true
            opacity: root.light ? 0.35 : 0.3
            BlurBackdrop { width: root.width; height: root.height; source: root.cover; veil: 0; saturation: 0.1 }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.3; color: root.alpha(root.skyLow, 0) }
                    GradientStop { position: 1.0; color: root.skyLow }
                }
            }
        },
        // the sun's glow, then the sun, half set
        Glow {
            x: root.sunX - width / 2; y: root.horizon - height / 2
            width: root.sunR * 9; height: root.sunR * 5
            strength: root.light ? 0.4 : 0.35
        },
        Item {
            width: root.width; height: root.horizon
            clip: true
            Rectangle {
                x: root.sunX - root.sunR; y: root.horizon - root.sunR * 1.25
                width: root.sunR * 2; height: width; radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: root.mix(root.accent, "#ffffff", 0.5) }
                    GradientStop { position: 0.6; color: root.accent }
                }
            }
        },
        // water
        Rectangle {
            y: root.horizon; width: root.width; height: root.height - y
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.mix(root.skyLow, root.water, 0.45) }
                GradientStop { position: 0.35; color: root.water }
                GradientStop { position: 1.0; color: root.water }
            }
        },
        // the reflection: short horizontal strokes under the sun, narrowing with depth and shimmering slowly
        Repeater {
            model: 11
            Rectangle {
                readonly property real d: (index + 1) / 11
                readonly property int k: 1 + index % 3
                width: root.sunR * (1.9 - 1.3 * d) * (0.85 + 0.15 * Math.sin(root.t * k * 3 + index * 1.7))
                height: Math.max(1, (0.35 + 0.5 * d) * root.u)
                radius: height / 2
                x: root.sunX - width / 2 + 1.2 * root.u * Math.sin(root.t * k * 2 + index)
                y: root.horizon + 1.2 * root.u + Math.pow(d, 1.3) * 30 * root.u
                color: root.mix(root.accent, "#ffffff", 0.25)
                opacity: (1 - d * 0.85) * (0.45 + 0.25 * Math.sin(root.t * k * 4 + index * 2.3)) * (root.playing ? 1 : 0.6)
            }
        },
        // the horizon line
        Rectangle { y: root.horizon; width: root.width; height: 1; color: root.alpha(root.light ? "#ffffff" : root.accent, 0.35) }
    ]

    Cover {
        x: 14 * root.u; y: 14 * root.u
        width: 72 * root.u; height: width; radius: 1.2 * root.u
        source: root.cover; shadowStrength: 0.9
    }
    TrackInfo {
        x: 102 * root.u
        y: 14 * root.u - 1 * root.u
        width: 96 * root.u
        unit: root.u
        titleSize: 9
        titleLines: 3
        showProgress: false
        title: root.title; artist: root.artist; playing: root.playing
    }
    // progress, then the controls under it (the same order in every theme)
    Progress {
        id: bar
        x: 102 * root.u; y: 66 * root.u
        width: 170 * root.u
        unit: root.u
        theme: root
        value: root.progress; playing: root.playing
        leftText: root.elapsedText; rightText: root.remainingText
    }
    Controls {
        x: 102 * root.u; y: bar.y + bar.height + 1.2 * root.u
        width: 170 * root.u
        unit: root.u
        theme: root
    }
}
