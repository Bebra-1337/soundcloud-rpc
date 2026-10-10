import QtQuick
import QtQuick.Shapes

// Cassette: the track written by hand on the label of a tape, the reels turning in the window and the tape wound from
// one onto the other as the track plays; a tape counter beside it.
ThemeBase {
    id: root
    // the shell: smoke-black plastic on dark schemes, white plastic on light ones (physical object)
    readonly property color shellTop: light ? "#f7f7f5" : "#2b2b2b"
    readonly property color shellBottom: light ? "#e2e2de" : "#1b1b1b"
    readonly property color shellEdge: light ? "#c9c9c4" : "#3d3d3d"
    readonly property color recess: light ? "#d4d4cf" : "#121212"
    readonly property color paper: "#f1eee6"
    readonly property color pen: "#23252b"
    readonly property color tapeColor: "#4a3427"   // the tape, on the packs and in its run alike

    // The tape path, in the shell's coordinates (units of u). As in a real cassette the tape does not cross the window
    // from reel to reel: it leaves each pack on its outer side, runs down to a guide roller in a lower corner, around
    // it, and along the bottom edge past the head opening to the other roller. The packs shrink and grow with the
    // progress, so the tangents are worked out from their current radii. Only the stretches seen on a real cassette
    // are drawn: a short piece in the window by each pack and the run along the bottom.
    readonly property point hubL: Qt.point(41, 54)      // pack centres (the window sits at 30, 43)
    readonly property point hubR: Qt.point(105, 54)
    readonly property point rollerL: Qt.point(31, 88)
    readonly property point rollerR: Qt.point(115, 88)
    readonly property real rollerR_: 1.6
    function packRadius(amount) { return 4.75 + 4.75 * amount }    // 19u pack when full, 9.5u when empty
    // angle of the outer common tangent of a pack (c1, r1) and a roller (c2, r2); `side` picks the left or right one
    function tangentAngle(c1, r1, c2, r2, side) {
        var dx = c2.x - c1.x, dy = c2.y - c1.y
        var d = Math.sqrt(dx * dx + dy * dy)
        return Math.atan2(dy, dx) + side * Math.acos((r1 - r2) / d)
    }
    function onCircle(c, r, a) { return Qt.point((c.x + r * Math.cos(a)) * u, (c.y + r * Math.sin(a)) * u) }
    readonly property real tapeWidth: 0.7
    // How much of the tape is on the right reel: the progress, followed on a critically damped spring so a seek or a
    // new track rewinds the packs over a second or so instead of jumping, while steady playback is tracked without lag.
    property real wound: 0
    property real woundSpeed: 0
    Component.onCompleted: wound = progress
    FrameAnimation {
        running: Math.abs(root.progress - root.wound) > 0.00002 || Math.abs(root.woundSpeed) > 0.00002
        onTriggered: {
            const steps = 4
            const h = Math.min(frameTime, 0.05) / steps
            const w = 4
            let x = root.wound, v = root.woundSpeed
            for (let i = 0; i < steps; ++i) {
                v += (w * w * (root.progress - x) - 2 * w * v) * h
                x += v * h
            }
            root.wound = x
            root.woundSpeed = v
        }
    }
    readonly property var tapeRun: {
        // the tape's centre line runs half a tape width inside the packs' edges, so the tape lies on the outer turn
        // instead of beside it
        var inset = tapeWidth / 2
        var rl = packRadius(1 - wound) - inset, rr = packRadius(wound) - inset, k = rollerR_ + inset
        var aL = tangentAngle(hubL, rl, rollerL, k, 1)     // left side of the left pack
        var aR = tangentAngle(hubR, rr, rollerR, k, -1)    // right side of the right pack
        var pts = []
        // the outer turn of the left pack, coming round to where the tape leaves it
        for (var a = 0; a <= 10; a++) pts.push(onCircle(hubL, rl, aL + 1.2 * (1 - a / 10)))
        // around the left roller from the tangent down to its bottom (angle π/2), then the same on the right
        for (var i = 0; i <= 8; i++) pts.push(onCircle(rollerL, k, aL + (Math.PI / 2 - aL) * i / 8))
        for (var j = 0; j <= 8; j++) pts.push(onCircle(rollerR, k, Math.PI / 2 + (aR - Math.PI / 2) * j / 8))
        // onto the right pack and round its outer turn
        for (var b = 0; b <= 10; b++) pts.push(onCircle(hubR, rr, aR - 1.2 * b / 10))
        return pts
    }

    background: [
        Rectangle { anchors.fill: parent; color: root.bg },
        Glow {
            x: (root.width - 286 * root.u) / 2 - 20 * root.u; y: (root.height - 100 * root.u) / 2 - 40 * root.u
            width: 200 * root.u; height: 180 * root.u
            strength: root.light ? 0.1 : 0.07
        }
    ]

    component TapeLine: Shape {
        width: tape.width; height: tape.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.tapeColor
            strokeWidth: root.tapeWidth * root.u
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.FlatCap
            PathPolyline { path: root.tapeRun }
        }
    }
    component Roller: Rectangle {
        width: 2 * root.rollerR_ * root.u; height: width; radius: width / 2
        color: "#ecebe6"
        border.color: root.alpha("#000000", 0.25); border.width: 1
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.35; height: width; radius: width / 2; color: "#8a8a86" }
    }

    // A key of the deck's transport: a block of plastic with a lit face that stays down while its function is on
    // (play while playing, pause while paused), and dips when pressed.
    component DeckKey: Item {
        id: key
        property string icon
        property bool down: false
        signal pressed()
        readonly property bool sunk: down || keyArea.pressed
        height: 11 * root.u
        // the key's front edge, seen below its face
        Rectangle {
            y: 1.4 * root.u; width: parent.width; height: parent.height - 1.4 * root.u; radius: 0.8 * root.u
            color: root.light ? "#b9b9b4" : "#0c0c0c"
        }
        Rectangle {
            width: parent.width; height: parent.height - 1.6 * root.u
            y: key.sunk ? 1.2 * root.u : 0
            radius: 0.8 * root.u
            border.color: root.light ? "#c4c4bf" : "#4a4a4a"; border.width: 1
            gradient: Gradient {
                GradientStop { position: 0; color: key.sunk ? (root.light ? "#dcdcd7" : "#262626") : (root.light ? "#fbfbf9" : "#3d3d3d") }
                GradientStop { position: 1; color: key.sunk ? (root.light ? "#d0d0cb" : "#1e1e1e") : (root.light ? "#e4e4e0" : "#2b2b2b") }
            }
            Behavior on y { NumberAnimation { duration: 70 } }
            IdleIcon {
                anchors.centerIn: parent
                name: key.icon
                size: 4.2 * root.u
                color: key.down ? root.accent : (root.light ? "#3a3a3a" : "#d6d6d6")
            }
        }
        MouseArea {
            id: keyArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: key.pressed()
        }
    }

    component Screw: Rectangle {
        width: 3 * root.u; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: root.light ? "#d0d0cc" : "#5a5a5a" }
            GradientStop { position: 1; color: root.light ? "#9a9a96" : "#2c2c2c" }
        }
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.62; height: Math.max(1, 0.25 * root.u); color: root.light ? "#7d7d79" : "#1a1a1a"; rotation: 35 }
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.62; height: Math.max(1, 0.25 * root.u); color: root.light ? "#7d7d79" : "#1a1a1a"; rotation: 125 }
    }

    Item {
        id: tape
        x: 12 * root.u; y: 3.5 * root.u
        width: 146 * root.u; height: 93 * root.u

        Shadow { anchors.fill: parent; radius: 3.5 * root.u; strength: 0.8; offsetY: 2.5 * root.u }
        Rectangle {
            anchors.fill: parent; radius: 3.5 * root.u
            border.color: root.shellEdge; border.width: 1
            gradient: Gradient {
                GradientStop { position: 0; color: root.shellTop }
                GradientStop { position: 1; color: root.shellBottom }
            }
        }
        // the whole tape path, seen through the clear plastic of the shell; one color everywhere, the same as the
        // tape wound on the packs
        TapeLine { }
        // the raised lip along the bottom, where the head reaches the tape
        Shape {
            x: (tape.width - 96 * root.u) / 2; y: tape.height - 17 * root.u
            width: 96 * root.u; height: 17 * root.u
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.shellEdge; strokeWidth: 1
                fillColor: root.light ? "#ececE8" : "#222222"
                startX: 0; startY: 17 * root.u
                PathLine { x: 7 * root.u; y: 0 }
                PathLine { x: 89 * root.u; y: 0 }
                PathLine { x: 96 * root.u; y: 17 * root.u }
            }
        }
        Repeater {
            model: [24, 39, 48, 57, 72]
            Rectangle {
                x: tape.width / 2 + (modelData - 48) * root.u - width / 2; y: tape.height - 9 * root.u
                width: (index === 2 ? 5 : 3.2) * root.u; height: width; radius: index === 2 ? 0.6 * root.u : width / 2
                color: root.recess
            }
        }
        // the bottom opening: guide rollers and the tape running along the edge between them
        Roller { x: (root.rollerL.x - root.rollerR_) * root.u; y: (root.rollerL.y - root.rollerR_) * root.u }
        Roller { x: (root.rollerR.x - root.rollerR_) * root.u; y: (root.rollerR.y - root.rollerR_) * root.u }
        Item {
            x: 25 * root.u; y: 76 * root.u; width: 96 * root.u; height: 17 * root.u
            clip: true
            TapeLine { x: -25 * root.u; y: -76 * root.u }
        }
        Screw { x: 3 * root.u; y: 3 * root.u }
        Screw { x: tape.width - 6 * root.u; y: 3 * root.u }
        Screw { x: 3 * root.u; y: tape.height - 6 * root.u }
        Screw { x: tape.width - 6 * root.u; y: tape.height - 6 * root.u }
        Screw { x: (tape.width - width) / 2; y: tape.height - 15 * root.u }

        // the paper label, above the window so it hides none of the tape's path
        Rectangle {
            id: label
            x: 8 * root.u; y: 7 * root.u
            width: tape.width - 16 * root.u; height: 35 * root.u
            radius: 1.2 * root.u
            color: root.paper
            border.color: root.alpha("#000000", 0.08); border.width: 1

            // printed band, in the accent
            Rectangle {
                width: parent.width; height: 8 * root.u; radius: parent.radius
                color: root.accent
                Rectangle { y: parent.height - height; width: parent.width; height: parent.radius; color: parent.color }
                IdleText {
                    x: 3 * root.u; anchors.verticalCenter: parent.verticalCenter
                    text: "A"; color: root.onAccent; size: 5 * root.u; weight: 800
                }
                IdleText {
                    x: parent.width - width - 3 * root.u; anchors.verticalCenter: parent.verticalCenter
                    text: "C·60   HIGH BIAS   70μs"; color: root.onAccent; opacity: 0.8
                    size: 2.3 * root.u; weight: 600; tracking: 0.12
                }
            }
            // ruled lines, written on by hand
            Repeater {
                model: 2
                Rectangle {
                    x: 4 * root.u; y: (20 + index * 9) * root.u
                    width: label.width - 34 * root.u; height: 1
                    color: root.alpha("#5b6b8c", 0.35)
                }
            }
            IdleText {
                x: 4.5 * root.u; y: 9.5 * root.u
                width: label.width - 36 * root.u
                text: root.title || qsTr("Nothing playing")
                serif: true; font.italic: true
                size: 8.6 * root.u
                color: root.pen
                elide: Text.ElideRight
            }
            IdleText {
                x: 4.5 * root.u; y: 21.5 * root.u
                width: label.width - 36 * root.u
                text: root.artist
                serif: true; font.italic: true
                size: 5.6 * root.u
                color: root.alpha(root.pen, 0.75)
                elide: Text.ElideRight
            }
            // the cover as a sticker on the label
            Cover {
                x: label.width - 27 * root.u; y: 11 * root.u
                width: 23 * root.u; height: width; radius: 0.4 * root.u
                source: root.cover; shadowStrength: 0.25
            }
        }

        // the window: smoked plastic with the two reels behind it
        Rectangle {
            id: win
            x: 30 * root.u; y: 43 * root.u
            width: 86 * root.u; height: 22 * root.u
            radius: height / 2
            color: root.light ? "#3b3936" : "#0c0c0c"
            border.color: root.alpha("#000000", 0.35); border.width: 1
            clip: true

            // the wound tape on both reels, drawn as exact circles in the tape path's coordinates: a Rectangle of
            // fractional size centered with anchors snaps to whole pixels, so the packs grew in steps and stood off
            // their hubs and off the tape by half a pixel at times
            Shape {
                x: -30 * root.u; y: -43 * root.u
                width: tape.width; height: tape.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.tapeColor; strokeColor: "transparent"
                    PathAngleArc {
                        centerX: root.hubL.x * root.u; centerY: root.hubL.y * root.u
                        radiusX: root.packRadius(1 - root.wound) * root.u; radiusY: radiusX
                        startAngle: 0; sweepAngle: 360
                    }
                }
                ShapePath {
                    fillColor: root.tapeColor; strokeColor: "transparent"
                    PathAngleArc {
                        centerX: root.hubR.x * root.u; centerY: root.hubR.y * root.u
                        radiusX: root.packRadius(root.wound) * root.u; radiusY: radiusX
                        startAngle: 0; sweepAngle: 360
                    }
                }
            }
            Repeater {
                model: 2
                Item {
                    width: 19 * root.u; height: width
                    x: index === 0 ? 1.5 * root.u : win.width - width - 1.5 * root.u
                    y: (win.height - height) / 2
                    // the hub with its teeth, turning
                    Item {
                        anchors.centerIn: parent
                        width: parent.width * 0.42; height: width
                        RotationAnimator on rotation { from: 0; to: -360; duration: 3200; loops: Animation.Infinite; running: root.playing }
                        Rectangle { anchors.fill: parent; radius: width / 2; color: "#eeeeea" }
                        Repeater {
                            model: 6
                            Rectangle {
                                x: parent.width / 2 - width / 2; y: parent.height * 0.12
                                width: parent.width * 0.14; height: parent.height * 0.22
                                color: "#2a2a2a"
                                transform: Rotation { origin.x: width / 2; origin.y: parent.height * 0.38; angle: index * 60 }
                            }
                        }
                        Rectangle { anchors.centerIn: parent; width: parent.width * 0.3; height: width; radius: width / 2; color: "#2a2a2a" }
                    }
                }
            }
            // the tape leaving each pack toward its roller (the window sits at 30, 43 in the shell)
            TapeLine { x: -30 * root.u; y: -43 * root.u }
            // a reflection across the window plastic (rounded like the window: clip only cuts a rectangle)
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.1) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }
    }

    // tape counter
    Column {
        x: 178 * root.u; width: 94 * root.u
        anchors.verticalCenter: tape.verticalCenter
        IdleText {
            //: label of the tape counter showing the time left
            text: qsTr("Counter")
            color: root.alpha(root.ink, 0.55)
            size: 2.4 * root.u; weight: 600; tracking: 0.14
            font.capitalization: Font.AllUppercase
        }
        Item { width: 1; height: 2.5 * root.u }
        Rectangle {
            width: parent.width; height: 24 * root.u; radius: 1.6 * root.u
            color: root.light ? root.mix(root.bg, root.ink, 0.04) : root.mix(root.bg, "#000000", 0.4)
            border.color: root.alpha(root.ink, 0.1); border.width: 1
            // recessed: a shade along the top inner edge
            Rectangle {
                x: 1; y: 1; width: parent.width - 2; height: 4 * root.u; radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: root.alpha("#000000", root.light ? 0.06 : 0.3) }
                    GradientStop { position: 1; color: root.alpha("#000000", 0) }
                }
            }
            IdleText {
                anchors.centerIn: parent
                text: root.remainingText
                size: 14 * root.u; weight: 400; tracking: -0.01; tabular: true
            }
        }
        Item { width: 1; height: 4 * root.u }
        Progress {
            width: parent.width; unit: root.u; value: root.progress; playing: root.playing; theme: root
            leftText: root.elapsedText; rightText: root.fmt(root.duration)
        }
        Item { width: 1; height: 2.5 * root.u }
        // the deck's transport keys
        Row {
            spacing: 1 * root.u
            readonly property real keyW: (94 * root.u - 3 * spacing) / 4
            DeckKey { width: parent.keyW; icon: "prev"; onPressed: root.requestPrevious() }
            DeckKey { width: parent.keyW; icon: "play"; down: root.playing; onPressed: if (!root.playing) root.requestTogglePlay() }
            DeckKey { width: parent.keyW; icon: "pause"; down: !root.playing; onPressed: if (root.playing) root.requestTogglePlay() }
            DeckKey { width: parent.keyW; icon: "next"; onPressed: root.requestNext() }
        }
        Controls { width: parent.width; unit: root.u; theme: root; transport: false }
    }
}
