import QtQuick

// Stereo: a pair of backlit VU meters, left and right channel, their needles swinging with the level of each side
// (with the weight and overshoot of a real needle). The track sits in a column beside them.
ThemeBase {
    id: root

    // loudness of one channel 0..1 from its normalised spectrum (mean square, so the bass carries as it does on a meter)
    function loudness(arr) {
        if (!arr || !arr.length) return 0
        var s = 0
        for (var i = 0; i < arr.length; i++) s += arr[i] * arr[i] * (i < 12 ? 1.4 : 0.8)
        return Math.min(1, Math.sqrt(s / arr.length) * 1.25)
    }
    readonly property real levelL: loudness(bandsL)
    readonly property real levelR: loudness(bandsR)

    background: [
        Rectangle { anchors.fill: parent; color: root.bg },
        Glow {
            x: (root.width - 286 * root.u) / 2 + 191 * root.u - width / 2
            y: (root.height - 100 * root.u) / 2 + 50 * root.u - height / 2
            width: 200 * root.u; height: 120 * root.u
            color: "#ffb35c"
            strength: root.light ? 0.08 : 0.06 + 0.04 * root.level
        }
    ]

    // One meter. The scale is the classic VU one: -20 .. +3, with 0 VU at about 70% of the arc and the red zone above
    // it (here the accent).
    component Meter: Item {
        id: meter
        property string channel
        property real level: 0
        readonly property real faceH: height - 2 * bezel
        readonly property real bezel: 2.2 * root.u
        // position of a dB value on the scale, 0..1
        function pos(db) { return (Math.pow(10, db / 20) - 0.1) / (Math.pow(10, 3 / 20) - 0.1) }

        Shadow { anchors.fill: parent; radius: 2.4 * root.u; strength: 0.7 }
        // bezel
        Rectangle {
            anchors.fill: parent; radius: 2.4 * root.u
            gradient: Gradient {
                GradientStop { position: 0; color: root.light ? "#e9e9e7" : "#2e2e2e" }
                GradientStop { position: 1; color: root.light ? "#c4c4c0" : "#151515" }
            }
            border.color: root.light ? "#b5b5b0" : "#3a3a3a"; border.width: 1
        }
        // the face, lit from behind
        Item {
            id: face
            x: meter.bezel; y: meter.bezel
            width: meter.width - 2 * meter.bezel; height: meter.faceH
            clip: true
            Rectangle {
                anchors.fill: parent; radius: 1.2 * root.u
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f6eedb" }
                    GradientStop { position: 0.7; color: "#efe2c3" }
                    GradientStop { position: 1; color: "#e2d0a8" }
                }
            }
            Canvas {
                id: scale
                anchors.fill: parent
                property color red: root.accent
                onRedChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d")
                    c.reset()
                    var px = width / 2, py = height * 1.18, R = height * 0.88
                    var a0 = -Math.PI / 2 - 0.7, a1 = -Math.PI / 2 + 0.7
                    function ang(p) { return a0 + (a1 - a0) * p }
                    var u = height / 46
                    // arc: black up to 0 VU, a thick red band above
                    c.lineWidth = Math.max(1, 0.28 * u)
                    c.strokeStyle = "#2b2620"
                    c.beginPath(); c.arc(px, py, R, ang(0), ang(meter.pos(0))); c.stroke()
                    c.lineWidth = 1.6 * u
                    c.strokeStyle = Qt.rgba(red.r, red.g, red.b, 1)
                    c.beginPath(); c.arc(px, py, R + 0.65 * u, ang(meter.pos(0)), ang(1)); c.stroke()
                    // ticks and figures
                    var major = [-20, -10, -7, -5, -3, 0, 3], minor = [-2, -1, 1, 2]
                    c.fillStyle = "#2b2620"
                    c.textAlign = "center"
                    c.textBaseline = "alphabetic"
                    c.font = "500 " + Math.round(3.6 * u) + "px 'Inter Variable'"
                    var all = major.concat(minor)
                    for (var i = 0; i < all.length; i++) {
                        var db = all[i], isMajor = major.indexOf(db) >= 0
                        var a = ang(meter.pos(db))
                        var r0 = R - (isMajor ? 3.2 : 2) * u, r1 = R
                        c.strokeStyle = db > 0 ? Qt.rgba(red.r, red.g, red.b, 1) : "#2b2620"
                        c.lineWidth = Math.max(1, (isMajor ? 0.32 : 0.22) * u)
                        c.beginPath()
                        c.moveTo(px + Math.cos(a) * r0, py + Math.sin(a) * r0)
                        c.lineTo(px + Math.cos(a) * r1, py + Math.sin(a) * r1)
                        c.stroke()
                        if (isMajor) {
                            var rt = R + 4.2 * u
                            c.fillStyle = db > 0 ? Qt.rgba(red.r, red.g, red.b, 1) : "#2b2620"
                            c.fillText(db > 0 ? "+" + db : "" + Math.abs(db), px + Math.cos(a) * rt, py + Math.sin(a) * rt + 1.2 * u)
                        }
                    }
                    // the minus and plus signs at the ends, and the legend
                    c.fillStyle = "#2b2620"
                    c.font = "600 " + Math.round(3 * u) + "px 'Inter Variable'"
                    c.fillText("−", px + Math.cos(a0) * (R - 7 * u), py + Math.sin(a0) * (R - 7 * u))
                    c.fillStyle = Qt.rgba(red.r, red.g, red.b, 1)
                    c.fillText("+", px + Math.cos(a1) * (R - 7 * u), py + Math.sin(a1) * (R - 7 * u))
                    c.fillStyle = "#2b2620"
                    c.font = "500 " + Math.round(7 * u) + "px 'Cormorant Garamond'"
                    c.fillText("VU", px, height * 0.7)
                }
            }
            IdleText {
                x: 2.4 * root.u; y: face.height - height - 1.6 * root.u
                text: meter.channel
                color: "#2b2620"; size: 3 * root.u; weight: 700; tracking: 0.1
            }
            // the needle, pivoting below the face; it rests against the left stop in silence
            Item {
                x: face.width / 2; y: face.height * 1.18
                Rectangle {
                    id: needle
                    x: -width / 2; y: -height
                    width: Math.max(1, 0.32 * root.u); height: face.height * 1.06
                    antialiasing: true
                    color: "#1c1a17"
                    transformOrigin: Item.Bottom
                    rotation: -44 + 84 * Math.max(0, Math.min(1.04, meter.level))
                    Behavior on rotation { SpringAnimation { spring: 2.2; damping: 0.32; mass: 1.2; epsilon: 0.05 } }
                }
            }
            // the hub cover and the glass
            Rectangle {
                x: (face.width - width) / 2; y: face.height - height / 2
                width: 14 * root.u; height: 9 * root.u; radius: height / 2
                color: root.light ? "#3a3a3a" : "#1a1a1a"
            }
            Rectangle {
                anchors.fill: parent; radius: 1.2 * root.u
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.28) }
                    GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.85; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.12) }
                }
            }
        }
    }

    Meter {
        x: 112 * root.u; y: 12 * root.u
        width: 78 * root.u; height: 52 * root.u
        channel: "L"; level: root.levelL
    }
    Meter {
        x: 194 * root.u; y: 12 * root.u
        width: 78 * root.u; height: 52 * root.u
        channel: "R"; level: root.levelR
    }
    // the amplifier's front panel under the meters: progress, then the controls under it
    Progress {
        id: bar
        x: 112 * root.u; y: 68 * root.u
        width: 160 * root.u
        unit: root.u
        theme: root
        value: root.progress; playing: root.playing
        leftText: root.elapsedText; rightText: root.remainingText
    }
    Controls {
        x: 112 * root.u; y: bar.y + bar.height + 1.2 * root.u
        width: 160 * root.u
        unit: root.u
        theme: root
        align: Qt.AlignHCenter
    }

    Cover {
        x: 14 * root.u; y: 14 * root.u
        width: 32 * root.u; height: width; radius: 1 * root.u
        source: root.cover; shadowStrength: 0.6
    }
    TrackInfo {
        x: 14 * root.u
        y: 86 * root.u - height + 0.9 * root.u
        width: 84 * root.u
        unit: root.u
        showProgress: false
        titleSize: 6.4
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
