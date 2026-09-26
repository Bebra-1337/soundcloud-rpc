import QtQuick

Item {
    id: bar
    property real value: 0
    property color color: "white"
    height: 6
    Rectangle { anchors.fill: parent; radius: height / 2; color: "#33ffffff" }
    Rectangle { width: parent.width * bar.value; height: parent.height; radius: height / 2; color: bar.color }
}
