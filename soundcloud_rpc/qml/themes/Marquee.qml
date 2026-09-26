import QtQuick

// Endlessly scrolling line of text (dir: 1 = right, -1 = left).
Item {
    id: m
    property string text
    property real px: 30
    property int dir: 1
    property int loopMs: 30000
    property color color: "white"
    property bool outline: false

    height: tm.height
    clip: true

    TextMetrics { id: tm; text: m.text + "   •   "; font.pixelSize: m.px; font.weight: Font.Black }

    Row {
        id: row
        Repeater {
            model: tm.width > 0 ? Math.ceil(m.width / tm.width) + 2 : 0
            Text {
                text: tm.text
                font: tm.font
                color: m.outline ? "transparent" : m.color
                style: m.outline ? Text.Outline : Text.Normal
                styleColor: m.color
            }
        }
    }
    NumberAnimation {
        target: row
        property: "x"
        from: m.dir > 0 ? -tm.width : 0
        to: m.dir > 0 ? 0 : -tm.width
        duration: m.loopMs
        loops: Animation.Infinite
        running: tm.width > 0
    }
}
