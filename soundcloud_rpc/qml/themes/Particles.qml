import QtQuick
import QtQuick.Effects
import QtQuick.Particles

ThemeBase {
    id: root

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#0a0a0a" }
            GradientStop { position: 1; color: Qt.darker(root.accent2, 4) }
        }
    }

    ParticleSystem { id: ps; running: true; paused: !root.playing }
    Emitter {
        system: ps
        x: 0; y: root.height; width: root.width; height: 1
        emitRate: 22
        lifeSpan: 9000; lifeSpanVariation: 3000
        size: 26; sizeVariation: 20; endSize: 4
        velocity: AngleDirection { angle: -90; angleVariation: 18; magnitude: root.height / 9; magnitudeVariation: 30 }
    }
    ImageParticle {
        system: ps
        source: "qrc:///particleresources/glowdot.png"
        color: root.accent; colorVariation: 0.5; alpha: 0.5
    }

    Column {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY
        spacing: 4 * root.u
        Item {
            width: 40 * root.u; height: width
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.5; height: width; radius: width / 2
                color: root.accent; opacity: 0.22
                layer.enabled: true; layer.smooth: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
            }
            Cover { anchors.fill: parent; radius: 2 * root.u; source: root.cover }
        }
        Meta { width: 70 * root.u; unit: root.u; title: root.title; artist: root.artist; remainingText: root.remainingText }
    }
}
