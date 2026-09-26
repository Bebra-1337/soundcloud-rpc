import QtQuick
import QtQuick.Effects
import QtQuick.Particles

ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; brightness: -0.55; contrast: 0.1 },
        ParticleSystem { id: ps; running: true; paused: !root.playing },
        Emitter {
            system: ps
            x: 0; y: root.height + 10; width: root.width; height: 1
            emitRate: 42
            lifeSpan: 11000; lifeSpanVariation: 3000
            size: 30 * root.u / 5.2; sizeVariation: 24; endSize: 4
            velocity: AngleDirection { angle: -90; angleVariation: 14; magnitude: root.height / 11; magnitudeVariation: 26 }
        },
        ImageParticle {
            system: ps
            source: "qrc:///particleresources/glowdot.png"
            color: "white"; colorVariation: 0.0; alpha: 0.75; entryEffect: ImageParticle.Fade
        },
        Vignette { strength: 0.7 },
        Grain { }
    ]

    Item {
        x: 16 * root.u + root.driftX
        y: 10 * root.u + root.driftY
        width: 80 * root.u; height: width
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.5; height: width; radius: width / 2
            color: "white"; opacity: 0.12
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
