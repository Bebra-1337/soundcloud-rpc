import QtQuick

// A slider's thumb of liquid glass: a solid white pill at rest that turns into a clear magnifying lens while it is
// dragged (`active`), swelling on a spring and stretching along its velocity. `source` is the slider's own track
// (a GlassSource with padding around it), so the lens magnifies the line under it.
LiquidGlass {
    id: knob

    property bool active: false
    property real grow: 1.45
    property real lens: active ? 1 : 0
    Behavior on lens { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    readonly property bool dark: 0.2126 * palette.window.r + 0.7152 * palette.window.g + 0.0722 * palette.window.b <= 0.45

    follow: true
    radius: height / 2
    tint: Qt.rgba(1, 1, 1, 1 - 0.9 * lens)
    saturation: 1.15
    brightness: 1.0 + 0.04 * lens
    magnify: 1 + 0.5 * lens
    thickness: height * (0.17 + 0.33 * lens)
    bezel: height * 0.3
    dispersion: 0.07 * lens
    rimLight: 0.5 + 1.0 * lens
    shadowOpacity: (dark ? 0.45 : 0.2) * (1 - 0.5 * lens)
    shadowRadius: height * 0.42
    shadowOffset: height * 0.12

    scale: active ? grow : 1
    Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.22; epsilon: 0.001 } }

    property real _vx: 0
    property real _lastX: x
    readonly property real _stretch: Math.min(0.24, Math.abs(_vx) / 3500) * lens

    transform: Scale {
        origin.x: knob.width / 2
        origin.y: knob.height / 2
        xScale: 1 + knob._stretch
        yScale: 1 - knob._stretch * 0.5
    }

    FrameAnimation {
        running: knob.visible
        onTriggered: {
            const v = (knob.x - knob._lastX) / Math.max(frameTime, 0.001)
            knob._lastX = knob.x
            knob._vx += (v - knob._vx) * Math.min(1, frameTime * 14)
        }
    }
}
