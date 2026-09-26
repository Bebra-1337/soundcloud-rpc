import QtQuick

ThemeBase {
    id: root

    background: [
        BlurBackdrop { anchors.fill: parent; source: root.cover; brightness: -0.6; contrast: 0.1 },
        Column {
            y: (root.height - height) / 2
            width: root.width
            Marquee { width: parent.width; text: root.title.toUpperCase(); px: 26 * root.u; dir: -1; loopMs: 46000; color: "#f2f2f2" }
            Marquee { width: parent.width; text: root.artist.toUpperCase(); px: 26 * root.u; dir: 1; loopMs: 62000; color: "#bdbdbd"; outline: true }
            Marquee { width: parent.width; text: root.title.toUpperCase(); px: 26 * root.u; dir: -1; loopMs: 80000; color: "#5a5a5a" }
        },
        Vignette { strength: 0.7 },
        Grain { }
    ]

    Rectangle {
        x: 14 * root.u + root.driftX; y: 62 * root.u
        width: 112 * root.u; height: 30 * root.u; radius: 3 * root.u
        color: "#ee0f0f0f"; border.color: "#33ffffff"
        Cover { x: 4 * root.u; y: 4 * root.u; width: 22 * root.u; height: width; radius: 1.6 * root.u; source: root.cover; shadow: false }
        Column {
            x: 31 * root.u; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 36 * root.u
            spacing: 0.6 * root.u
            Text { text: root.remainingText; color: root.ink; font.pixelSize: 9 * root.u; font.family: "monospace"; font.weight: Font.Bold }
            Progress { width: parent.width; unit: root.u; value: root.progress; labels: false }
        }
    }
}
