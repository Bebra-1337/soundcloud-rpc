import QtQuick

// Turntable: a record set large and cut by the window's edge, the cover as its label turning at 33⅓ rpm while the
// music plays, a tonearm whose stylus moves from the lead-in toward the label as the track progresses. The grooves and
// the light on them stay put (a turning record looks still except for its label).
ThemeBase {
    id: root
    readonly property real dia: 112 * u
    readonly property real cx: 46 * u
    readonly property real cy: 50 * u
    // tonearm angle: off the record when paused, from the outer groove (19.5°, the stylus at 0.95 of the radius) to
    // the inner one by the label (48°, 0.38) over the track
    readonly property real armTarget: playing ? 19.5 + 28.5 * progress : 4
    // The arm follows on a critically damped spring: it eases into a swing on and off the record and out of it again,
    // tracks the progress without lag while playing, and is not restarted by the position's updates every frame
    // (a Behavior was, and barely moved).
    property real armAngle: 4
    property real armSpeed: 0
    readonly property real armOmega: 5
    Component.onCompleted: armAngle = armTarget
    FrameAnimation {
        running: Math.abs(root.armTarget - root.armAngle) > 0.005 || Math.abs(root.armSpeed) > 0.005
        onTriggered: {
            const steps = 4
            const h = Math.min(frameTime, 0.05) / steps
            const w = root.armOmega
            let x = root.armAngle, v = root.armSpeed
            for (let i = 0; i < steps; ++i) {
                v += (w * w * (root.armTarget - x) - 2 * w * v) * h
                x += v * h
            }
            root.armAngle = x
            root.armSpeed = v
        }
    }
    readonly property color metalHi: light ? "#d9d9d9" : "#a8a8a8"
    readonly property color metalLo: light ? "#8f8f8f" : "#565656"

    background: [
        Rectangle { anchors.fill: parent; color: root.bg },
        Glow {
            x: (root.width - 286 * root.u) / 2 + root.cx - width / 2
            y: (root.height - 100 * root.u) / 2 + root.cy - height / 2
            width: root.dia * 1.7; height: width
            strength: root.light ? 0.14 : 0.1
        }
    ]

    Item {
        id: rec
        x: root.cx - root.dia / 2; y: root.cy - root.dia / 2
        width: root.dia; height: root.dia

        Shadow { anchors.fill: parent; radius: width / 2; strength: 0.9; offsetY: 2.5 * root.u }

        // the disc and its grooves, painted once
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                var R = width / 2
                c.translate(R, R)
                var g = c.createRadialGradient(0, 0, 0, 0, 0, R)
                g.addColorStop(0, "#1a1a1a"); g.addColorStop(0.9, "#101010"); g.addColorStop(1, "#151515")
                c.fillStyle = g
                c.beginPath(); c.arc(0, 0, R, 0, Math.PI * 2); c.fill()
                // grooves: fine rings, with smooth bands between the songs on the side
                var gaps = [0.83, 0.71, 0.6, 0.5]
                for (var r = R * 0.965; r > R * 0.37; r -= 1.15) {
                    var f = r / R, gap = false
                    for (var i = 0; i < gaps.length; i++) if (Math.abs(f - gaps[i]) < 0.006) gap = true
                    c.strokeStyle = gap ? "rgba(0,0,0,0.5)" : (Math.round(r) % 2 ? "rgba(255,255,255,0.035)" : "rgba(0,0,0,0.35)")
                    c.lineWidth = 0.8
                    c.beginPath(); c.arc(0, 0, r, 0, Math.PI * 2); c.stroke()
                }
                // the rim
                c.strokeStyle = "rgba(255,255,255,0.08)"; c.lineWidth = 1
                c.beginPath(); c.arc(0, 0, R - 0.5, 0, Math.PI * 2); c.stroke()
            }
        }
        // light on the grooves: two narrow reflections opposite each other and a broad soft one
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d")
                c.reset()
                var R = width / 2
                var g = c.createConicalGradient(R, R, -Math.PI * 0.3)
                g.addColorStop(0.00, "rgba(255,255,255,0)")
                g.addColorStop(0.06, "rgba(255,255,255,0.13)")
                g.addColorStop(0.12, "rgba(255,255,255,0)")
                g.addColorStop(0.30, "rgba(255,255,255,0.03)")
                g.addColorStop(0.50, "rgba(255,255,255,0)")
                g.addColorStop(0.56, "rgba(255,255,255,0.1)")
                g.addColorStop(0.62, "rgba(255,255,255,0)")
                g.addColorStop(1.00, "rgba(255,255,255,0)")
                c.fillStyle = g
                c.beginPath()
                c.arc(R, R, R * 0.97, 0, Math.PI * 2)
                c.arc(R, R, R * 0.36, 0, Math.PI * 2, true)
                c.fill()
            }
        }
        // the label: the cover, turning; pre-rendered into a 2x texture so the turning edge stays smooth
        Item {
            anchors.centerIn: parent
            width: root.dia * 0.34; height: width
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            RotationAnimator on rotation { from: 0; to: 360; duration: 1800; loops: Animation.Infinite; running: root.playing }
            Cover { anchors.fill: parent; radius: width / 2; source: root.cover; shadow: false; edge: false }
        }
        // spindle
        Rectangle {
            anchors.centerIn: parent
            width: 1.8 * root.u; height: width; radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#e6e6e6" }
                GradientStop { position: 1; color: "#7a7a7a" }
            }
        }
    }

    // tonearm: pivot top right of the record; everything below turns about it
    Item {
        x: 118 * root.u; y: 12 * root.u
        Item {
            id: arm
            width: 0; height: 0
            rotation: root.armAngle
            // counterweight behind the pivot
            Rectangle {
                x: -3.2 * root.u; y: -12 * root.u
                width: 6.4 * root.u; height: 8 * root.u; radius: 0.8 * root.u
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.metalLo }
                    GradientStop { position: 0.45; color: root.metalHi }
                    GradientStop { position: 1; color: root.metalLo }
                }
            }
            // the tube
            Rectangle {
                x: -0.6 * root.u; y: -5 * root.u
                width: 1.2 * root.u; height: 66 * root.u
                radius: width / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.metalLo }
                    GradientStop { position: 0.4; color: root.metalHi }
                    GradientStop { position: 1; color: root.metalLo }
                }
            }
            // headshell and cartridge, angled like a real one
            Item {
                y: 60 * root.u
                rotation: 22
                transformOrigin: Item.TopLeft
                Rectangle {
                    x: -2 * root.u; y: 0
                    width: 4 * root.u; height: 9.5 * root.u; radius: 0.6 * root.u
                    color: root.light ? "#3a3a3a" : "#262626"
                    border.color: root.alpha("#ffffff", 0.08); border.width: 1
                }
                Rectangle {
                    x: -1.5 * root.u; y: 5.4 * root.u
                    width: 3 * root.u; height: 3.4 * root.u; radius: 0.3 * root.u
                    color: root.accent
                }
                // finger lift
                Rectangle {
                    x: 1.8 * root.u; y: 1.2 * root.u
                    width: 2.6 * root.u; height: 0.7 * root.u; radius: height / 2
                    color: root.metalHi
                }
            }
        }
        // the pivot housing sits on top of the arm
        Rectangle {
            x: -5.5 * root.u; y: -5.5 * root.u
            width: 11 * root.u; height: width; radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: root.metalHi }
                GradientStop { position: 1; color: root.metalLo }
            }
            border.color: root.alpha(root.light ? "#000000" : "#ffffff", 0.08); border.width: 1
            Rectangle {
                anchors.centerIn: parent
                width: 5 * root.u; height: width; radius: width / 2
                color: root.light ? "#4a4a4a" : "#1c1c1c"
            }
        }
    }

    TrackInfo {
        x: 136 * root.u
        y: (100 * root.u - height) / 2
        width: 136 * root.u
        unit: root.u
        theme: root
        titleSize: 9.6
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: root.remainingText
    }
}
