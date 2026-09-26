import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root

    Rectangle { anchors.fill: parent; color: "#111" }
    Image {
        id: bg; anchors.fill: parent; source: root.cover; visible: false
        sourceSize.width: 200; sourceSize.height: 200; fillMode: Image.PreserveAspectCrop; asynchronous: true
    }
    MultiEffect { anchors.fill: parent; source: bg; blurEnabled: true; blur: 1.0; blurMax: 64; brightness: -0.5; saturation: -1; scale: 1.2 }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.driftY
        width: root.width
        spacing: 1 * root.u
        Marquee { width: parent.width; text: root.title.toUpperCase(); px: 16 * root.u; dir: -1; loopMs: 40000; color: "white" }
        Marquee { width: parent.width; text: root.artist.toUpperCase(); px: 16 * root.u; dir: 1; loopMs: 55000; color: root.accent; outline: true }
        Marquee { width: parent.width; text: root.title.toUpperCase(); px: 16 * root.u; dir: -1; loopMs: 70000; color: "white"; opacity: 0.35 }
    }

    Row {
        x: 5 * root.u; y: root.height - height - 5 * root.u
        spacing: 2 * root.u
        Cover { width: 14 * root.u; height: width; radius: 1 * root.u; source: root.cover }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: root.remainingText; color: "white"; font.pixelSize: 6 * root.u; font.family: "monospace"; font.weight: Font.Bold }
            Bar { width: 30 * root.u; height: 0.6 * root.u; value: root.progress; color: root.accent }
        }
    }
}
