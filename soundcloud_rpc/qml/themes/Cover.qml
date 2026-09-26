import QtQuick
import QtQuick.Effects

// Rounded (optionally circular) cover with drop shadow, hairline border and a fade-in on every new image.
Item {
    id: cov
    property url source
    property real radius: 0
    property bool shadow: true
    property real shadowStrength: 0.6

    Shadow {
        anchors.fill: parent
        visible: cov.shadow
        radius: cov.radius
        offsetY: cov.height * 0.06
        strength: cov.shadowStrength * fx.opacity
    }
    Image {
        id: img
        anchors.fill: parent
        source: cov.source
        sourceSize.width: 700
        sourceSize.height: 700
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        onStatusChanged: if (status === Image.Ready) fade.restart()
    }
    Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: cov.radius; color: "black" }
    }
    Rectangle {
        anchors.fill: parent
        radius: cov.radius
        color: "#22ffffff"
        visible: img.status !== Image.Ready
        Text {
            anchors.centerIn: parent
            text: "♪"
            color: "#55ffffff"
            font.pixelSize: cov.height * 0.42
        }
    }
    MultiEffect {
        id: fx
        anchors.fill: parent
        source: img
        visible: img.status === Image.Ready
        maskEnabled: true
        maskSource: mask
    }
    Rectangle {
        anchors.fill: parent
        radius: cov.radius
        color: "transparent"
        border.color: "#26ffffff"
        border.width: 1
    }
    NumberAnimation { id: fade; target: fx; property: "opacity"; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
}
