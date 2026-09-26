import QtQuick

// Title / artist / remaining-time text block.
Column {
    id: m
    property string title
    property string artist
    property string remainingText
    property real unit: 7
    property int align: Text.AlignHCenter
    property color color: "white"
    property bool showRemaining: true
    spacing: unit * 0.8

    Text {
        width: m.width
        text: m.title || "Nothing playing"
        color: m.color
        font.pixelSize: m.unit * 5
        font.weight: Font.Bold
        horizontalAlignment: m.align
        elide: Text.ElideRight
    }
    Text {
        width: m.width
        text: m.artist
        visible: text !== ""
        color: m.color
        opacity: 0.7
        font.pixelSize: m.unit * 3.4
        horizontalAlignment: m.align
        elide: Text.ElideRight
    }
    Text {
        width: m.width
        visible: m.showRemaining
        text: m.remainingText
        color: m.color
        opacity: 0.9
        font.pixelSize: m.unit * 3.4
        font.family: "monospace"
        horizontalAlignment: m.align
    }
}
