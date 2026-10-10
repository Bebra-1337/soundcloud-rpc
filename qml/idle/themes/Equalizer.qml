import QtQuick
import QtQuick.Shapes

// Spectrum: the live spectrum of the track (32 log-spaced bands, drawn as one smooth curve across the whole window)
// doubles as the progress bar: the part already played is lit in the accent, a fine playhead marks the position, and
// a dotted line holds the recent peaks. Silent or paused, the curve settles flat.
ThemeBase {
    id: root
    readonly property int points: 160
    readonly property real base: (height - 100 * u) / 2 + 77 * u   // the curve's floor, in window coordinates
    readonly property real span: 29 * u                              // its full height
    readonly property real sx: Math.round((width - 286 * u) / 2)      // the stage's left edge
    property var caps: []
    property var curve: []      // points of the spectrum line, window coordinates
    property var peaks: []

    // spectrum at x (0..1), cosine-interpolated between the bands so the curve has no corners
    function spectrum(x) {
        var b = root.bands
        if (!b || b.length === 0) return 0
        var p = x * (b.length - 1)
        var i = Math.floor(p), f = p - i
        var a = b[i], c = b[Math.min(i + 1, b.length - 1)]
        var w = (1 - Math.cos(f * Math.PI)) / 2
        return a + (c - a) * w
    }

    Timer {
        interval: 33; repeat: true; running: true
        onTriggered: {
            var line = [], pk = [], caps = []
            var any = false
            for (var i = 0; i < root.points; i++) {
                var x = i / (root.points - 1)
                // the ends taper to the floor, so the curve starts and ends on the window's edges cleanly
                var taper = Math.min(1, Math.min(x, 1 - x) * 14)
                var v = root.spectrum(x) * taper
                var c = i < root.caps.length ? root.caps[i] : 0
                c = Math.max(v, c - 0.008)
                if (c > 0.004) any = true
                caps.push(c)
                line.push(Qt.point(x * root.width, root.base - v * root.span))
                pk.push(Qt.point(x * root.width, root.base - c * root.span - 0.8 * root.u))
            }
            if (!any && root.caps.length && root.curve.length) return
            root.caps = caps
            root.curve = line
            root.peaks = pk
        }
    }

    background: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: root.bg }
                GradientStop { position: 1; color: root.light ? root.mix(root.bg, root.ink, 0.04) : root.mix(root.bg, "#000000", 0.35) }
            }
        },
        // the spectrum is a backdrop: full window width, under the cover and the text
        Item {
            x: 0; y: 0; width: root.width; height: root.height
            // played
            Item {
                width: root.width * root.progress; height: root.height
                clip: true
                Spectrum { tone: root.playing ? root.accent : root.inkFaint; fillStrength: root.light ? 0.35 : 0.42 }
            }
            // still to come
            Item {
                x: root.width * root.progress; width: root.width - x; height: root.height
                clip: true
                Spectrum { x: -parent.x; tone: root.ink; fillStrength: root.light ? 0.1 : 0.12; opacity: root.light ? 0.4 : 0.32 }
            }
            // peak hold
            Shape {
                width: root.width; height: root.height
                opacity: root.light ? 0.22 : 0.18
                ShapePath {
                    strokeColor: root.ink
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [1, 3]
                    fillColor: "transparent"
                    startX: 0; startY: root.base - 0.8 * root.u
                    PathPolyline { path: root.peaks }
                }
            }
            // the floor and the playhead, with the time at its head and the length at the floor's end
            Rectangle { y: root.base; width: root.width; height: 1; color: root.alpha(root.ink, 0.14) }
            Rectangle {
                id: playhead
                x: Math.round(root.width * (seek.pressed ? seek.value : root.progress)); y: root.base - root.span - 4 * root.u
                width: 1; height: root.span + 4 * root.u
                color: root.alpha(root.ink, 0.35)
            }
            IdleText {
                x: Math.max(root.sx + 14 * root.u, Math.min(root.sx + 272 * root.u - width, playhead.x - width / 2))
                y: playhead.y - height - 0.8 * root.u
                text: seek.pressed ? root.fmt(seek.value * root.duration)
                      : (root.playing ? "" : qsTr("Paused") + "  ·  ") + root.elapsedText
                color: root.alpha(root.ink, 0.7)
                size: 2.6 * root.u; weight: 500; tracking: 0.02; tabular: true
            }
            IdleText {
                x: root.sx + 272 * root.u - width; y: root.base + 1.4 * root.u
                text: root.fmt(root.duration)
                color: root.alpha(root.ink, 0.45)
                size: 2.6 * root.u; weight: 500; tracking: 0.02; tabular: true
            }
            // the spectrum is the seek bar: click or drag anywhere on it
            MouseArea {
                id: seek
                property real value: 0
                y: root.base - root.span - 4 * root.u
                width: root.width; height: root.span + 6 * root.u
                cursorShape: Qt.PointingHandCursor
                function at(x) { return Math.max(0, Math.min(1, x / width)) }
                onPressed: (e) => value = at(e.x)
                onPositionChanged: (e) => { if (pressed) value = at(e.x) }
                onReleased: (e) => root.requestSeek(at(e.x) * root.duration)
            }
        }
    ]

    // One spectrum drawing, twice: in the accent clipped to the played part, quietly in the text color for the rest.
    component Spectrum: Shape {
        property color tone
        property real fillStrength
        width: root.width; height: root.height
        preferredRendererType: Shape.GeometryRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: root.base - root.span; x2: 0; y2: root.base
                GradientStop { position: 0; color: Qt.rgba(tone.r, tone.g, tone.b, fillStrength) }
                GradientStop { position: 1; color: Qt.rgba(tone.r, tone.g, tone.b, 0) }
            }
            startX: 0; startY: root.base
            PathPolyline { path: root.curve }
            PathLine { x: root.width; y: root.base }
        }
        ShapePath {
            strokeColor: tone
            strokeWidth: Math.max(1.5, 0.35 * root.u)
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: 0; startY: root.base
            PathPolyline { path: root.curve }
        }
    }

    Cover {
        x: 14 * root.u; y: 12 * root.u
        width: 30 * root.u; height: width; radius: 1 * root.u
        source: root.cover; shadowStrength: 0.6
    }
    TrackInfo {
        x: 52 * root.u
        y: 12 * root.u + (30 * root.u - height) / 2
        width: 160 * root.u
        unit: root.u
        titleSize: 7.4
        titleLines: 1
        showProgress: false
        title: root.title; artist: root.artist; playing: root.playing
    }
    IdleText {
        x: 272 * root.u - width
        y: 12 * root.u + (30 * root.u - height) / 2
        text: root.remainingText
        size: 7.4 * root.u; weight: 300; tracking: -0.02; tabular: true
    }
    // the spectrum is the progress; the controls sit under it, as in every theme
    Controls {
        x: 14 * root.u; y: 83 * root.u
        width: 258 * root.u
        unit: root.u
        theme: root
    }
}
