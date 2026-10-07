import QtQuick

// Common contract for every idle theme: the host sets the track properties, the theme only draws.
//
// Themes are designed for a wide banner window (the reference size is 1431x500, ~2.86:1). Content goes
// into a 286x100 "stage" (1 unit `u` = 1% of its height) that is scaled to fit and centered, so other
// window sizes stay correct, only letterboxed. Full-bleed backdrops go into `background`.
Item {
    id: base

    property string title: ""
    property string artist: ""
    property url cover: ""
    property real position: 0
    property real duration: 1
    property bool playing: true

    readonly property real remaining: Math.max(0, duration - position)
    readonly property real progress: duration > 0 ? Math.min(1, position / duration) : 0
    readonly property string elapsedText: fmt(position)
    readonly property string remainingText: "-" + fmt(remaining)
    readonly property real u: Math.max(0.1, Math.min(width / 286, height / 100))

    // Monochrome palette (noctalia "Monochrome"); the cover is the only color on screen.
    readonly property color ink: "#f2f2f2"
    readonly property color inkDim: "#a3a3a3"
    readonly property color inkFaint: "#6b6b6b"
    readonly property color surface: "#111111"
    readonly property color outline: "#3c3c3c"

    // Audio (raw 0..1 band levels from the page's analyser, ~30 per second; all zero when there is no signal).
    // The raw levels sit high and move little (bass is ~0.5-0.8 for most of a track), so they are normalised
    // against a slowly adapting floor/ceiling; `bass`, `mid`, `treble`, `level` are the normalised and smoothed
    // values (fast attack, slow release) and `beat` is a pulse that jumps to 1 on a kick and decays.
    property real audioBass: 0
    property real audioMid: 0
    property real audioTreble: 0
    property real audioLevel: 0
    property var audioBands: []   // raw 32-band spectrum (log-spaced, 40 Hz .. 16 kHz), 0..1 each
    property var bands: []        // the same, normalised per band and smoothed
    property var audioBandsL: []  // raw left / right channel spectra
    property var audioBandsR: []
    property var bandsL: []       // normalised and smoothed; both channels share one scale, so sound that plays
    property var bandsR: []       // in one ear only lights up one side
    property real bass: 0
    property real mid: 0
    property real treble: 0
    property real level: 0
    property real beat: 0
    signal beatDetected()

    QtObject {
        id: reactor
        property var lo: [1, 1, 1, 1]
        property var hi: [0, 0, 0, 0]
        property var cur: [0, 0, 0, 0]
        property real prevBass: 0
        property double lastBeatMs: 0
        property double lastFeedMs: 0
        property bool live: false
        property var bandLo: []
        property var bandHi: []
        property var bandCur: []
        property var stLo: []
        property var stHi: []
        property var curL: []
        property var curR: []

        function norm(i, v) {
            // the floor rises slowly to meet the signal, the ceiling falls slowly; a minimum range avoids
            // amplifying noise during silence
            lo[i] = Math.min(v, lo[i] + 0.0015)
            hi[i] = Math.max(v, hi[i] - 0.0015)
            return Math.max(0, Math.min(1, (v - lo[i]) / Math.max(0.12, hi[i] - lo[i])))
        }
        function smooth(i, target) {
            var k = target > cur[i] ? 0.6 : 0.16
            cur[i] = cur[i] + (target - cur[i]) * k
            return cur[i]
        }

        // Per-band floor/ceiling so every band uses its full range (music is bass-heavy, raw highs are tiny). Both
        // adapt slowly, otherwise a sustained note would sag to nothing; the ceiling recovers a little faster so a
        // quieter track after a loud one is not held down for long. Bars fall quickly (release 0.32).
        function feedBands() {
            var raw = base.audioBands
            if (!raw || !raw.length) return
            var out = []
            for (var i = 0; i < raw.length; i++) {
                if (bandLo.length <= i) { bandLo[i] = 1; bandHi[i] = 0; bandCur[i] = 0 }
                var v = raw[i]
                bandLo[i] = Math.min(v, bandLo[i] + 0.0004)
                bandHi[i] = Math.max(v, bandHi[i] - 0.001)
                var n = Math.max(0, Math.min(1, (v - bandLo[i]) / Math.max(0.15, bandHi[i] - bandLo[i])))
                bandCur[i] += (n - bandCur[i]) * (n > bandCur[i] ? 0.6 : 0.32)
                out.push(bandCur[i])
            }
            base.bands = out
        }
        // Left and right share one floor/ceiling per band (taken from the louder channel), so the balance survives.
        function feedStereo() {
            var L = base.audioBandsL, R = base.audioBandsR
            if (!L || !R || !L.length || L.length !== R.length) return
            var outL = [], outR = []
            for (var i = 0; i < L.length; i++) {
                if (stLo.length <= i) { stLo[i] = 1; stHi[i] = 0; curL[i] = 0; curR[i] = 0 }
                var vl = L[i], vr = R[i]
                stLo[i] = Math.min(Math.min(vl, vr), stLo[i] + 0.0004)
                stHi[i] = Math.max(Math.max(vl, vr), stHi[i] - 0.001)
                var range = Math.max(0.15, stHi[i] - stLo[i])
                var nl = Math.max(0, Math.min(1, (vl - stLo[i]) / range))
                var nr = Math.max(0, Math.min(1, (vr - stLo[i]) / range))
                curL[i] += (nl - curL[i]) * (nl > curL[i] ? 0.6 : 0.32)
                curR[i] += (nr - curR[i]) * (nr > curR[i] ? 0.6 : 0.32)
                outL.push(curL[i]); outR.push(curR[i])
            }
            base.bandsL = outL
            base.bandsR = outR
        }
        // no updates (paused, silence, analyser stopped, track skipped): fall back to 0, and stop once there
        function decay() {
            prevBass = 0
            var peak = 0
            var arrays = [bandCur, curL, curR]
            for (var k = 0; k < arrays.length; k++)
                for (var i = 0; i < arrays[k].length; i++) {
                    arrays[k][i] *= 0.6
                    if (arrays[k][i] < 0.002) arrays[k][i] = 0
                    peak = Math.max(peak, arrays[k][i])
                }
            if (bandCur.length) base.bands = bandCur.slice()
            if (curL.length) { base.bandsL = curL.slice(); base.bandsR = curR.slice() }
            base.bass = smooth(0, 0)
            base.mid = smooth(1, 0)
            base.treble = smooth(2, 0)
            base.level = smooth(3, 0)
            peak = Math.max(peak, base.bass, base.mid, base.treble, base.level)
            if (peak < 0.002) live = false
        }
        function feed() {
            var b = norm(0, base.audioBass), m = norm(1, base.audioMid)
            var t = norm(2, base.audioTreble), l = norm(3, base.audioLevel)
            var now = Date.now()
            lastFeedMs = now
            live = true
            feedBands()
            feedStereo()
            if (b > 0.55 && b - prevBass > 0.16 && now - lastBeatMs > 180) {
                lastBeatMs = now
                base.beat = 1
                beatDecay.restart()
                base.beatDetected()
            }
            prevBass = b
            base.bass = smooth(0, b)
            base.mid = smooth(1, m)
            base.treble = smooth(2, t)
            base.level = smooth(3, l)
        }
    }
    onAudioLevelChanged: reactor.feed()
    Timer {
        interval: 50; repeat: true
        running: reactor.live
        onTriggered: if (Date.now() - reactor.lastFeedMs > 120) reactor.decay()
    }
    NumberAnimation { id: beatDecay; target: base; property: "beat"; from: 1; to: 0; duration: 280; easing.type: Easing.OutCubic }

    default property alias content: stage.data
    property alias background: backdrop.data

    // Slow looping phase 0..2π (60s) for decorative motion. Themes must use integer multipliers so the loop
    // is seamless. Never use it to move covers or text: sub-pixel drift shows up as jitter.
    property real t: 0
    NumberAnimation on t { from: 0; to: Math.PI * 2; duration: 60000; loops: Animation.Infinite }

    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        var m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    clip: true

    Item { id: backdrop; anchors.fill: parent }
    // snapped to whole pixels: a half-pixel offset would make every edge in the theme render soft
    Item {
        id: stage
        width: 286 * base.u; height: 100 * base.u
        x: Math.round((base.width - width) / 2); y: Math.round((base.height - height) / 2)
    }
}
