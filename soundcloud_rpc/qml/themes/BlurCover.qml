import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root

    Rectangle { anchors.fill: parent; color: "#111" }
    Image {
        id: bg
        anchors.fill: parent
        source: root.cover
        sourceSize.width: 240
        sourceSize.height: 240
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: bg
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.3
        saturation: -1
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { from: 1.25; to: 1.4; duration: 40000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.4; to: 1.25; duration: 40000; easing.type: Easing.InOutSine }
        }
    }
    Rectangle { anchors.fill: parent; color: "#44000000" }

    Column {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY
        spacing: 4 * root.u
        Cover { width: 44 * root.u; height: width; radius: 1.5 * root.u; source: root.cover; anchors.horizontalCenter: parent.horizontalCenter }
        Meta {
            width: 70 * root.u
            unit: root.u
            title: root.title; artist: root.artist; remainingText: root.remainingText
            showRemaining: false
        }
        Item {
            width: 60 * root.u; height: 5 * root.u
            anchors.horizontalCenter: parent.horizontalCenter
            Bar { width: parent.width; value: root.progress; color: "white"; height: 0.8 * root.u }
            Text {
                y: 1.6 * root.u; anchors.right: parent.right
                text: root.remainingText; color: "white"; opacity: 0.8
                font.pixelSize: 3 * root.u; font.family: "monospace"
            }
        }
    }
}
