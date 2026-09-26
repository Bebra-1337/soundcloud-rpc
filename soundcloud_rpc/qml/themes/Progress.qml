import QtQuick

// Thin progress bar with a knob and elapsed / remaining labels underneath.
Item {
    id: p
    property real unit: 5
    property real value: 0
    property string leftText: ""
    property string rightText: ""
    property color color: "#f2f2f2"
    property color track: "#2effffff"
    property color labelColor: "#9a9a9a"
    property bool labels: true

    height: labels ? unit * 5.4 : unit * 1.8

    Rectangle {
        id: trk
        y: p.unit * 0.5
        width: p.width
        height: p.unit * 0.7
        radius: height / 2
        color: p.track
        Rectangle {
            id: fill
            width: Math.max(height, parent.width * p.value)
            height: parent.height
            radius: height / 2
            color: p.color
            Behavior on width { NumberAnimation { duration: 220 } }
        }
        Rectangle {
            width: p.unit * 1.7; height: width; radius: width / 2
            color: p.color
            anchors.verticalCenter: parent.verticalCenter
            x: fill.width - width / 2
        }
    }
    Text {
        visible: p.labels
        y: p.unit * 2.5
        text: p.leftText
        color: p.labelColor
        font.pixelSize: p.unit * 2.7
        font.family: "monospace"
    }
    Text {
        visible: p.labels
        y: p.unit * 2.5
        x: p.width - width
        text: p.rightText
        color: p.labelColor
        font.pixelSize: p.unit * 2.7
        font.family: "monospace"
    }
}
