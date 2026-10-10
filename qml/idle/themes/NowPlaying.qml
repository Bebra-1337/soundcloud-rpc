import QtQuick

// Small letterspaced status label ("Now playing" / "Paused") after an accent dot that is filled while playing.
Item {
    id: np
    property real unit: 5
    property bool playing: true
    property int align: Text.AlignLeft
    property color color: Qt.rgba(palette.windowText.r, palette.windowText.g, palette.windowText.b, 0.6)

    height: unit * 3

    Row {
        spacing: np.unit * 1.2
        anchors.verticalCenter: parent.verticalCenter
        x: np.align === Text.AlignRight ? np.width - width : (np.align === Text.AlignHCenter ? (np.width - width) / 2 : 0)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: np.unit * 1.1; height: width; radius: width / 2
            color: np.playing ? palette.accent : "transparent"
            border.color: np.playing ? palette.accent : np.color
            border.width: Math.max(1, np.unit * 0.2)
        }
        IdleText {
            anchors.verticalCenter: parent.verticalCenter
            text: np.playing ? qsTr("Now playing") : qsTr("Paused")
            color: np.color
            size: np.unit * 2.4
            font.capitalization: Font.AllUppercase
            weight: 600
            tracking: 0.14
        }
    }
}
