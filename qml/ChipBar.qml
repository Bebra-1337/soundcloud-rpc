import QtQuick

// A row of filter chips: [{ key, label }, ...].
Row {
    id: bar

    property var chips: []
    property string current
    signal picked(string key)

    spacing: 8

    Repeater {
        model: bar.chips
        Rectangle {
            id: chip
            required property var modelData
            readonly property bool active: modelData.key === bar.current
            height: 30
            width: label.implicitWidth + 28
            radius: 15
            color: active ? Style.accent : (hh.hovered ? Style.hover : Style.raised)
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                id: label
                anchors.centerIn: parent
                text: chip.modelData.label
                color: chip.active ? Style.onAccent : Style.ink
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: bar.picked(chip.modelData.key) }
        }
    }
}
