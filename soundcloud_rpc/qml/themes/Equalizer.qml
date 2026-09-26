import QtQuick

// Real spectrum of the playing track (32 log-spaced bands from the page's analyser, drawn as 92 interpolated
// bars) with peak caps that hold and fall. Silent or paused: the bars sink to a thin line.
ThemeBase {
    id: root
    readonly property int barCount: 92
    property var caps: []

    function spectrum(x) {
        var b = root.bands
        if (!b || b.length === 0) return 0
        var p = x * (b.length - 1)
        var i = Math.floor(p), f = p - i
        var a = b[i], c = b[Math.min(i + 1, b.length - 1)]
        return a + (c - a) * f
    }

    // peak caps: jump up with the bar, fall slowly
    Timer {
        interval: 33; repeat: true; running: true
        onTriggered: {
            var next = []
            var any = false
            for (var i = 0; i < root.barCount; i++) {
                var v = root.spectrum(i / (root.barCount - 1))
                var c = i < root.caps.length ? root.caps[i] : 0
                c = Math.max(v, c - 0.014)
                if (c > 0.004) any = true
                next.push(c)
            }
            if (any || root.caps.length) root.caps = next
        }
    }

    background: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#1a1a1a" }
                GradientStop { position: 1; color: "#080808" }
            }
        },
        Vignette { strength: 0.6 },
        Grain { }
    ]

    Repeater {
        model: root.barCount
        Item {
            readonly property real v: root.spectrum(index / (root.barCount - 1))
            readonly property real cap: index < root.caps.length ? root.caps[index] : 0
            width: (286 - 20) * root.u / root.barCount - 0.5 * root.u
            x: 10 * root.u + index * (286 - 20) * root.u / root.barCount
            height: 38 * root.u
            y: 98 * root.u - height

            Rectangle {
                width: parent.width
                height: Math.max(0.7 * root.u, parent.v * 38 * root.u)
                y: parent.height - height
                radius: width / 2
                Behavior on height { NumberAnimation { duration: 60 } }
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f2f2f2" }
                    GradientStop { position: 1; color: "#4a4a4a" }
                }
                opacity: 0.9
            }
            Rectangle {
                width: parent.width; height: 0.5 * root.u; radius: height / 2
                y: parent.height - Math.max(0.7 * root.u, parent.cap * 38 * root.u) - 1.6 * root.u
                color: "#f2f2f2"
                opacity: parent.cap > 0.02 ? 0.85 : 0
            }
        }
    }

    Cover {
        x: 14 * root.u; y: 8 * root.u
        width: 54 * root.u; height: width; radius: 2.4 * root.u; source: root.cover
    }
    TrackInfo {
        x: 84 * root.u
        y: 8 * root.u
        width: 187 * root.u
        unit: root.u; titleSize: 9
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
