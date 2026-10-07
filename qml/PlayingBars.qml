import QtQuick

// Small "now playing" equalizer next to the current track.
Row {
    id: bars

    property bool running: true
    property color color: Style.accent

    spacing: 2
    height: 14

    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: 3
            radius: 1
            y: bars.height - height
            height: bars.height * 0.4
            color: bars.color
            SequentialAnimation on height {
                running: bars.running
                loops: Animation.Infinite
                NumberAnimation { to: bars.height; duration: 320 + index * 110; easing.type: Easing.InOutSine }
                NumberAnimation { to: bars.height * 0.25; duration: 290 + index * 80; easing.type: Easing.InOutSine }
            }
        }
    }
}
