import QtQuick

// Slim volume slider of the idle controls: click or drag to set, the wheel nudges it. The fill is the accent, gray
// while muted; the knob shows under the pointer.
Item {
    id: v
    property Item theme
    property real unit: 5
    property bool glass: false        // the track as a groove cut into glass
    property bool liquid: false       // the knob as a pill of liquid glass that magnifies the track while dragged
    readonly property real value: theme ? theme.volume : 0
    readonly property color ink: palette.windowText
    height: 8.8 * unit

    function setFrom(x) { v.theme.requestVolume(Math.max(0, Math.min(1, x / v.width))) }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: (v.glass ? 0.9 : 0.55) * v.unit; radius: height / 2
        color: v.glass ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(v.ink.r, v.ink.g, v.ink.b, 0.16)
        border.width: v.glass ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.22)
        Rectangle {
            width: Math.max(height, parent.width * v.value); height: parent.height; radius: height / 2
            color: v.theme && v.theme.muted ? Qt.rgba(v.ink.r, v.ink.g, v.ink.b, 0.4) : palette.accent
        }
    }
    Rectangle {
        visible: (area.containsMouse || area.pressed) && !v.liquid
        width: 2.4 * v.unit; height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: v.value * (v.width - width)
        color: v.ink
    }
    Loader {
        active: v.liquid
        anchors.fill: parent
        sourceComponent: Item {
            GlassSource { id: trackSource; sourceItem: track; padding: v.unit * 6 }
            GlassKnob {
                source: trackSource
                width: v.unit * 3.6; height: v.unit * 2.3
                x: v.width * v.value - width / 2
                y: (v.height - height) / 2
                active: area.pressed
                opacity: area.containsMouse || area.pressed ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (e) => v.setFrom(e.x)
        onPositionChanged: (e) => { if (pressed) v.setFrom(e.x) }
        onWheel: (w) => v.theme.requestVolume(Math.max(0, Math.min(1, v.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
