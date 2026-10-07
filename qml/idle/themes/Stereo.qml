import QtQuick
import QtQuick.Effects

// Stereo mirror: the left channel's spectrum on the left half, the right channel's on the right, bass at the
// centre and highs at the edges. Sound that plays in one ear only lights up one side. The analyser is a blurred
// backdrop, half the window tall, behind the cover and the text. Peak caps hold and fall.
ThemeBase {
    id: root
    readonly property int perSide: 46
    property var capsL: []
    property var capsR: []
    readonly property real maxBar: 50 * u                          // half the window height
    readonly property real sy: Math.round((height - 100 * u) / 2)

    // spectrum value at position 0 (bass) .. 1 (highs), linearly interpolated between the 32 bands
    function at(arr, pos) {
        if (!arr || arr.length === 0) return 0
        var p = pos * (arr.length - 1)
        var i = Math.floor(p), f = p - i
        var a = arr[i], c = arr[Math.min(i + 1, arr.length - 1)]
        return a + (c - a) * f
    }
    function posOf(index) { return index / (root.perSide - 1) }   // 0 at the centre .. 1 at the edge

    Timer {
        interval: 33; repeat: true; running: true
        onTriggered: {
            var nl = [], nr = []
            var any = false
            for (var i = 0; i < root.perSide; i++) {
                var cl = i < root.capsL.length ? root.capsL[i] : 0
                var cr = i < root.capsR.length ? root.capsR[i] : 0
                cl = Math.max(root.at(root.bandsL, root.posOf(i)), cl - 0.014)
                cr = Math.max(root.at(root.bandsR, root.posOf(i)), cr - 0.014)
                if (cl > 0.004 || cr > 0.004) any = true
                nl.push(cl); nr.push(cr)
            }
            if (any || root.capsL.length) { root.capsL = nl; root.capsR = nr }
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
        // The analyser: one bar per (side, index); on the left side index 0 is at the centre, bars run outwards.
        Item {
            x: 0; y: 0; width: root.width; height: root.height
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 16 }
            Repeater {
                model: root.perSide * 2
                Item {
                    readonly property bool leftSide: index < root.perSide
                    readonly property int k: leftSide ? index : index - root.perSide
                    readonly property real v: root.at(leftSide ? root.bandsL : root.bandsR, root.posOf(k))
                    readonly property var capArray: leftSide ? root.capsL : root.capsR
                    readonly property real cap: capArray.length > k ? capArray[k] : 0
                    // all 92 bars share the full window width with one constant gap, the centre included
                    readonly property real slot: root.width / (root.perSide * 2)
                    readonly property real gap: 0.5 * root.u
                    width: slot - gap
                    x: root.width / 2 + (leftSide ? -(k + 1) * slot : k * slot) + gap / 2
                    height: root.maxBar
                    y: root.sy + 98 * root.u - height

                    Rectangle {
                        width: parent.width
                        height: Math.max(0.7 * root.u, parent.v * root.maxBar)
                        y: parent.height - height
                        radius: width / 2
                        Behavior on height { NumberAnimation { duration: 60 } }
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#f2f2f2" }
                            GradientStop { position: 1; color: "#5a5a5a" }
                        }
                        opacity: 0.85
                    }
                    Rectangle {
                        width: parent.width; height: 0.5 * root.u; radius: height / 2
                        y: parent.height - Math.max(0.7 * root.u, parent.cap * root.maxBar) - 1.6 * root.u
                        color: "#f2f2f2"
                        opacity: parent.cap > 0.02 ? 0.8 : 0
                    }
                }
            }
        },
        Vignette { strength: 0.6 },
        Grain { }
    ]

    Cover {
        x: 14 * root.u; y: 8 * root.u
        width: 42 * root.u; height: width; radius: 2.2 * root.u; source: root.cover
    }
    TrackInfo {
        x: 68 * root.u
        y: 8 * root.u
        width: 203 * root.u
        unit: root.u; titleSize: 8.4
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
