import QtQuick

// Ripple: thin rings spread from the round cover like rings on water, one on every kick of the music (and a slow
// steady one while the music plays without a signal). Only the rings move.
ThemeBase {
    id: root
    readonly property real cx: 52 * u
    readonly property real cy: 50 * u
    readonly property real coverSize: 50 * u
    property int next: 0
    property double lastRipple: 0

    function ripple(strength) {
        var r = rings.itemAt(next)
        if (!r) return
        next = (next + 1) % rings.count
        lastRipple = Date.now()
        r.strength = strength
        r.anim.restart()
    }
    onBeatDetected: ripple(0.5 + 0.5 * bass)
    // without beats (silence, no analyser) a calm ripple every 2.4 s while playing
    Timer {
        interval: 600; repeat: true; running: root.playing
        onTriggered: if (Date.now() - root.lastRipple > 2400) root.ripple(0.45)
    }

    background: [
        Rectangle { anchors.fill: parent; color: root.bg },
        Glow {
            x: (root.width - 286 * root.u) / 2 + root.cx - width / 2
            y: (root.height - 100 * root.u) / 2 + root.cy - height / 2
            width: 130 * root.u; height: width
            strength: (root.light ? 0.14 : 0.1) * (1 + 0.8 * root.level)
        }
    ]

    Repeater {
        id: rings
        model: 8
        Rectangle {
            id: ring
            property real p: 1
            property real strength: 0.5
            property alias anim: grow
            readonly property real d: root.coverSize + p * 150 * root.u
            width: d; height: d; radius: d / 2
            x: root.cx - d / 2; y: root.cy - d / 2
            color: "transparent"
            border.color: root.accent
            border.width: Math.max(1, 0.3 * root.u)
            opacity: (1 - p) * (1 - p) * strength * (root.light ? 0.9 : 0.7)
            NumberAnimation { id: grow; target: ring; property: "p"; from: 0; to: 1; duration: 4200; easing.type: Easing.OutCubic }
        }
    }
    Cover {
        x: root.cx - width / 2; y: root.cy - height / 2
        width: root.coverSize; height: width; radius: width / 2
        source: root.cover; shadowStrength: 0.8
    }
    TrackInfo {
        x: 112 * root.u
        y: (100 * root.u - height) / 2
        width: 160 * root.u
        unit: root.u
        theme: root
        titleSize: 9.6
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
