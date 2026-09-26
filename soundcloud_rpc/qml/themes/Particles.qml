import QtQuick
import QtQuick.Effects
import QtQuick.Particles

// Rising glow dots. The light follows the music: dots and their glow brighten with the bass, burst on kicks, and the
// faint halo behind the cover and the floor glow breathe with the level. Only light reacts; the cover itself never moves.
ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; brightness: -0.55; contrast: 0.1 },
        // light rising from the floor where the dots are born
        Rectangle {
            y: root.height * 0.55; width: root.width; height: root.height - y
            opacity: 0.04 + 0.4 * root.level
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00ffffff" }
                GradientStop { position: 1.0; color: "#40ffffff" }
            }
        },
        // The dots are drawn as they are; a blurred snapshot of them is added on top as their glow. (Turning the
        // particle item itself into a layer squashed the whole particle field vertically.)
        Item {
            id: dots
            anchors.fill: parent
            ParticleSystem { id: ps; running: true; paused: !root.playing }
            Emitter {
                id: emitter
                system: ps
                x: 0; y: root.height + 10; width: root.width; height: 1
                emitRate: 18 + 60 * root.mid
                lifeSpan: 11000; lifeSpanVariation: 3000
                size: 30 * root.u / 5.2; sizeVariation: 24; endSize: 4
                velocity: AngleDirection { angle: -90; angleVariation: 14; magnitude: root.height / 11 * (1 + 0.6 * root.level); magnitudeVariation: 26 }
            }
            ImageParticle {
                system: ps
                source: "qrc:///particleresources/glowdot.png"
                color: "white"; colorVariation: 0.0
                alpha: 0.4 + 0.55 * root.bass
                entryEffect: ImageParticle.Fade
            }
            Connections {
                target: root
                function onBeatDetected() { emitter.burst(8 + Math.round(22 * root.bass)) }
            }
        },
        ShaderEffectSource { id: dotsSnapshot; anchors.fill: parent; sourceItem: dots; live: true; smooth: true; visible: false },
        // glow of the dots: a blurred copy that gets brighter and stronger with the bass
        MultiEffect {
            x: 0; y: 0; width: root.width; height: root.height  // explicit geometry: anchors squashed the copy
            source: dotsSnapshot
            blurEnabled: true
            blur: 1.0
            blurMax: 12
            brightness: 0.35
            opacity: 0.15 + 0.85 * root.bass
        },
        Vignette { strength: 0.7 },
        Grain { }
    ]

    Item {
        x: 16 * root.u
        y: 10 * root.u
        width: 80 * root.u; height: width
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.5; height: width; radius: width / 2
            color: "white"
            opacity: 0.04 + 0.1 * root.bass + 0.06 * root.beat
            scale: 1 + 0.05 * root.bass
            layer.enabled: true; layer.smooth: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
        }
        Cover { anchors.fill: parent; radius: 3 * root.u; source: root.cover }
    }
    TrackInfo {
        x: 112 * root.u
        y: (100 * root.u - height) / 2
        width: 161 * root.u
        unit: root.u; titleSize: 9.6
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
