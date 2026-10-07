import QtQuick

// Short message at the bottom of the window.
Rectangle {
    id: toast

    function show(text) {
        label.text = text
        opacity = 1
        hideTimer.restart()
    }

    width: Math.min(label.implicitWidth + 36, 560)
    height: 38
    radius: 19
    color: Style.raised
    border.color: Style.outline
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 524)
        elide: Text.ElideRight
        color: Style.ink
        font.pixelSize: 13
    }
    Timer {
        id: hideTimer
        interval: 3500
        onTriggered: toast.opacity = 0
    }
}
