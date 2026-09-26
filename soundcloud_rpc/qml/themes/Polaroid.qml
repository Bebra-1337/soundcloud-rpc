import QtQuick
import QtQuick.Effects

ThemeBase {
    id: root

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#222222" }
            GradientStop { position: 1; color: "#111111" }
        }
    }
    Canvas {
        anchors.fill: parent
        opacity: 0.5
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext("2d")
            c.reset()
            for (var i = 0; i < 2500; i++) {
                c.fillStyle = Math.random() > 0.5 ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.12)"
                c.fillRect(Math.random() * width, Math.random() * height, 2, 2)
            }
        }
    }

    Item {
        id: card
        width: 50 * root.u; height: 60 * root.u
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.driftX
        anchors.verticalCenterOffset: root.driftY
        rotation: -4
        SequentialAnimation on rotation {
            loops: Animation.Infinite
            NumberAnimation { to: 3; duration: 9000; easing.type: Easing.InOutSine }
            NumberAnimation { to: -4; duration: 9000; easing.type: Easing.InOutSine }
        }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowBlur: 1.0; shadowOpacity: 0.7; shadowVerticalOffset: 10 }

        Rectangle { anchors.fill: parent; color: "#d4d4d4" }
        Cover { x: 3 * root.u; y: 3 * root.u; width: parent.width - 6 * root.u; height: width; source: root.cover; shadow: false }
        Text {
            x: 3 * root.u; y: card.width - 0.5 * root.u + 1 * root.u; width: parent.width - 6 * root.u
            text: root.title || "Nothing playing"
            font.pixelSize: 3.8 * root.u; font.italic: true; font.weight: Font.DemiBold
            color: "#111111"; elide: Text.ElideRight
        }
        Text {
            x: 3 * root.u; y: card.width + 5.4 * root.u; width: parent.width - 6 * root.u
            text: root.artist + (root.artist ? "  ·  " : "") + root.remainingText
            font.pixelSize: 2.8 * root.u; font.italic: true
            color: "#555555"; elide: Text.ElideRight
        }
    }
}
