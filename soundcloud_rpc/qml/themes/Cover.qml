import QtQuick
import QtQuick.Effects

// Rounded (optionally circular) cover with drop shadow and a fade-in on every new image.
Item {
    id: cov
    property url source
    property real radius: 0
    property bool shadow: true

    Image {
        id: img
        anchors.fill: parent
        source: cov.source
        sourceSize.width: 600
        sourceSize.height: 600
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        onStatusChanged: if (status === Image.Ready) fade.restart()
    }
    Rectangle { id: mask; anchors.fill: parent; radius: cov.radius; visible: false; layer.enabled: true }
    Rectangle {
        anchors.fill: parent
        radius: cov.radius
        color: "#33ffffff"
        visible: img.status !== Image.Ready
    }
    MultiEffect {
        id: fx
        anchors.fill: parent
        source: img
        visible: img.status === Image.Ready
        maskEnabled: true
        maskSource: mask
        shadowEnabled: cov.shadow
        shadowColor: "black"
        shadowBlur: 1.0
        shadowOpacity: 0.6
        shadowVerticalOffset: cov.height * 0.03
    }
    NumberAnimation { id: fade; target: fx; property: "opacity"; from: 0; to: 1; duration: 700 }
}
