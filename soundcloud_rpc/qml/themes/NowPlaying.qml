import QtQuick

// Small letterspaced "NOW PLAYING" eyebrow with a mini equalizer that moves while playing.
Item {
    id: np
    property real unit: 5
    property bool playing: true
    property int align: Text.AlignLeft
    property color color: "#a3a3a3"

    height: unit * 3

    Row {
        spacing: np.unit * 0.9
        anchors.verticalCenter: parent.verticalCenter
        x: np.align === Text.AlignRight ? np.width - width : (np.align === Text.AlignHCenter ? (np.width - width) / 2 : 0)

        Item {
            width: np.unit * 2.6; height: np.unit * 2.2
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: 3
                Rectangle {
                    width: np.unit * 0.55; radius: width / 2; color: np.color
                    x: index * np.unit * 0.95
                    anchors.bottom: parent.bottom
                    height: np.unit * 0.7
                    SequentialAnimation on height {
                        running: np.playing
                        loops: Animation.Infinite
                        NumberAnimation { to: np.unit * (1.3 + index * 0.4); duration: 360 + index * 140; easing.type: Easing.InOutSine }
                        NumberAnimation { to: np.unit * 0.7; duration: 420 + index * 90; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: np.playing ? "Now playing" : "Paused"
            color: np.color
            font.pixelSize: np.unit * 2.3
            font.capitalization: Font.AllUppercase
            font.letterSpacing: np.unit * 0.45
            font.weight: Font.Medium
        }
    }
}
