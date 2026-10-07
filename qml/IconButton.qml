import QtQuick
import QtQuick.Controls.Basic

Item {
    id: btn

    property string icon
    property real size: 36
    property real iconSize: 20
    property color color: Style.inkDim
    property bool active: false   // highlighted (shuffle on, current page, ...)
    property bool filled: false
    property string tip

    signal clicked()

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ma.pressed ? Style.hover : (ma.containsMouse ? Style.raised : "transparent")
    }
    Icon {
        anchors.centerIn: parent
        name: btn.icon
        size: btn.iconSize
        filled: btn.filled
        color: btn.active ? Style.accent : (ma.containsMouse ? Style.ink : btn.color)
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
    ToolTip.visible: btn.tip !== "" && ma.containsMouse
    ToolTip.text: btn.tip
    ToolTip.delay: 700
}
