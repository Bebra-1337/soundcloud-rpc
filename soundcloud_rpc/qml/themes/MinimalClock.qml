import QtQuick

ThemeBase {
    id: root

    background: [
        Rectangle { anchors.fill: parent; color: "#050505" },
        Grain { amount: 0.06 }
    ]

    Row {
        x: 10 * root.u + root.driftX
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.driftY - 2 * root.u
        opacity: root.playing ? 1 : 0.4
        Behavior on opacity { NumberAnimation { duration: 700 } }
        spacing: 1 * root.u
        Text {
            y: 19 * root.u
            text: "−"; color: root.inkFaint
            font.pixelSize: 26 * root.u; font.weight: Font.Light; font.family: "monospace"
        }
        Text {
            text: root.remainingText.replace("-", "")
            color: root.ink
            font.pixelSize: 58 * root.u; font.weight: Font.Light; font.family: "monospace"
            font.letterSpacing: -2 * root.u
        }
    }
    Rectangle { x: 198 * root.u; y: 10 * root.u; width: 1; height: 80 * root.u; color: "#22ffffff" }
    Cover {
        x: 208 * root.u; y: 10 * root.u; width: 28 * root.u; height: width; radius: 1.6 * root.u; source: root.cover
        opacity: root.playing ? 1 : 0.5
    }
    TrackInfo {
        x: 208 * root.u; y: 45 * root.u; width: 70 * root.u
        unit: root.u; titleSize: 6; showEyebrow: false
        title: root.title; artist: root.artist; playing: root.playing
        progress: root.progress; elapsedText: root.elapsedText; remainingText: ""
    }
}
