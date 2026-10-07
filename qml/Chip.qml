import QtQuick

// A pill-shaped choice: accent-filled when it is the current one (ChipBar, settings).
Rectangle {
    id: chip

    property string text
    property bool active: false
    signal clicked()

    height: 30
    width: label.implicitWidth + 28
    radius: 15
    color: active ? Style.accent : (hh.hovered ? Style.hover : Style.raised)
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.active ? Style.onAccent : Style.ink
        font.pixelSize: 13
        font.weight: Font.Medium
    }
    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.clicked() }
}
