import QtQuick

// A round icon button for the idle themes: 44 px of hit area at the reference size, a quiet glyph that brightens
// under the pointer with a soft disc behind it, the accent when it is on (liked, shuffle, repeat). `primary` is
// the play button: an accent disc with the glyph in the accent's text color. `glass` makes the disc a pane of
// frosted glass (a light rim and a highlight along the top; the play button tinted with the accent), for themes
// built of glass, or with `glassSource` a lens of liquid glass.
Item {
    id: b
    property real unit: 5
    property string icon
    property bool active: false
    property bool filled: false
    property bool primary: false
    property string badge: ""          // a small mark in the corner ("1" for repeat one)
    property bool glass: false
    property GlassSource glassSource: null   // with `glass`: a lens of liquid glass refracting it
    signal clicked()

    readonly property color ink: palette.windowText
    readonly property bool light: 0.2126 * palette.window.r + 0.7152 * palette.window.g + 0.0722 * palette.window.b > 0.45
    readonly property color acc: palette.accent
    width: (primary ? 11 : 8.8) * unit
    height: width

    // Liquid glass buttons are jelly (as in the liquid-glass sample): pressed, the lens swells on an underdamped
    // spring, squashes and stretches with the spring's velocity and leans toward the pointer; released, it wobbles
    // back into shape. `_s`/`_v` are the spring's scale and velocity, `_pullX`/`_pullY` the lean (-1..1).
    readonly property bool liquid: glass && glassSource !== null
    property real pressScale: 1 + Math.min(0.18, 12 / Math.max(width, 1))
    property real _s: 1
    property real _v: 0
    property real _pullX: 0
    property real _pullY: 0
    readonly property real _stretch: Math.max(-0.16, Math.min(0.16, _v * 0.05))
    readonly property bool _settled: !area.pressed && Math.abs(_s - 1) < 0.0005 && Math.abs(_v) < 0.001
                                     && Math.abs(_pullX) < 0.001 && Math.abs(_pullY) < 0.001
    FrameAnimation {
        running: b.liquid && !b._settled
        onTriggered: {
            const target = area.pressed ? b.pressScale : 1
            const k = area.pressed ? 260 : 300
            const c = area.pressed ? 15 : 8
            const steps = 4
            const h = Math.min(frameTime, 0.05) / steps
            let s = b._s
            let v = b._v
            for (let i = 0; i < steps; ++i) {
                v += (-k * (s - target) - c * v) * h
                s += v * h
            }
            b._s = s
            b._v = v

            const px = area.pressed ? Math.max(-1, Math.min(1, (area.mouseX - b.width / 2) / (b.width / 2))) : 0
            const py = area.pressed ? Math.max(-1, Math.min(1, (area.mouseY - b.height / 2) / (b.height / 2))) : 0
            const a = Math.min(1, frameTime * 14)
            b._pullX += (px - b._pullX) * a
            b._pullY += (py - b._pullY) * a
        }
    }

    Rectangle {
        visible: !b.glass
        anchors.fill: parent
        radius: width / 2
        color: b.primary ? palette.accent : Qt.rgba(b.ink.r, b.ink.g, b.ink.b, area.containsMouse ? 0.1 : 0)
        scale: area.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
    // the lens and its glyph, transformed together by the jelly (identity when not liquid)
    Item {
        id: body
        anchors.fill: parent
        transform: [
            Scale {
                origin.x: b.width / 2
                origin.y: b.height / 2
                xScale: b._s * (1 + b._stretch + 0.07 * Math.abs(b._pullX) - 0.03 * Math.abs(b._pullY))
                yScale: b._s * (1 - b._stretch + 0.07 * Math.abs(b._pullY) - 0.03 * Math.abs(b._pullX))
            },
            Translate {
                x: b._pullX * Math.min(6, b.width * 0.08)
                y: b._pullY * Math.min(6, b.height * 0.08)
            }
        ]

        // liquid glass: a small lens over the backdrop; the play button is tinted with the accent
        Loader {
            active: b.liquid
            anchors.fill: parent
            sourceComponent: LiquidGlass {
                source: b.glassSource
                follow: !b._settled
                glow: area.pressed ? 0.3 : (area.containsMouse ? 0.08 : 0)
                Behavior on glow { NumberAnimation { duration: 180 } }
                glowPos: Qt.point(area.mouseX, area.mouseY)
                glowRadius: b.width * 0.6
                bezel: b.width * 0.3
                thickness: b.width * 0.32
                dispersion: 0.04
                tint: b.primary ? Qt.rgba(b.acc.r, b.acc.g, b.acc.b, area.containsMouse ? 0.9 : 0.8)
                                : (b.light ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.5 : 0.3)
                                           : Qt.rgba(1, 1, 1, area.containsMouse ? 0.14 : 0.05))
                saturation: 1.2
                rimLight: b.light ? 1.0 : 0.75
                shadowOpacity: b.light ? 0.12 : 0.3
                shadowRadius: 1.4 * b.unit
                shadowOffset: 0.4 * b.unit
            }
        }
        // glass: a translucent disc with a light rim, and a highlight over its upper half
        Item {
            visible: b.glass && b.glassSource === null
            anchors.fill: parent
            scale: area.pressed ? 0.92 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: b.primary ? Qt.rgba(b.acc.r, b.acc.g, b.acc.b, area.containsMouse ? 0.95 : 0.85)
                                 : (b.light ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.8 : 0.55)
                                            : Qt.rgba(1, 1, 1, area.containsMouse ? 0.17 : 0.09))
                border.width: 1
                border.color: b.primary ? Qt.rgba(1, 1, 1, 0.35)
                                        : (b.light ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.2))
                Behavior on color { ColorAnimation { duration: 140 } }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, b.primary ? 0.32 : (b.light ? 0.6 : 0.16)) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
            // a hairline of shade under the rim on light glass, so the disc reads against the pale card
            Rectangle {
                visible: b.light && !b.primary
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(b.ink.r, b.ink.g, b.ink.b, 0.07)
            }
        }
        IdleIcon {
            anchors.centerIn: parent
            name: b.icon
            size: (b.primary ? 5.2 : 4.4) * b.unit
            filled: b.filled
            color: b.primary ? palette.highlightedText : (b.active ? palette.accent : b.ink)
            opacity: b.primary || b.active || area.containsMouse ? 1 : 0.72
            scale: area.pressed && !b.liquid ? 0.92 : 1
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
        IdleText {
            visible: b.badge !== ""
            x: b.width * 0.68; y: b.height * 0.14
            text: b.badge
            color: palette.accent
            size: 2.2 * b.unit
            weight: 800
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
