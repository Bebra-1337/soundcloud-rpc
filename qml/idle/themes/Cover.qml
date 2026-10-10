import QtQuick
import QtQuick.Effects

// Rounded (optionally circular) cover with a soft two-layer shadow, a hairline inner edge and a fade-in on every new
// image. Without artwork it shows a quiet placeholder in the scheme's colors.
Item {
    id: cov
    property url source
    property real radius: 0
    property bool shadow: true
    property real shadowStrength: 0.6
    property bool edge: true
    readonly property color ink: palette.windowText
    readonly property bool ready: img.status === Image.Ready

    Shadow {
        anchors.fill: parent
        visible: cov.shadow
        radius: cov.radius
        strength: cov.shadowStrength * (cov.ready ? fx.opacity : 0.35)
    }
    Image {
        id: img
        anchors.fill: parent
        source: cov.source
        sourceSize.width: 900
        sourceSize.height: 900
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        mipmap: true
        onStatusChanged: if (status === Image.Ready) fade.restart()
    }
    // The mask is rasterised once into its own texture, which the window's MSAA does not reach: give it twice the
    // resolution, its own multisampling and smooth sampling, or the rounded corners look jagged (especially
    // when the cover is scaled).
    Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4
        layer.textureSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
        visible: false
        Rectangle { anchors.fill: parent; radius: cov.radius; color: "black"; antialiasing: true }
    }
    // placeholder: opaque, or the shadow underneath shows through as a gray smear
    Rectangle {
        anchors.fill: parent
        radius: cov.radius
        visible: !cov.ready
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.tint(palette.window, Qt.rgba(cov.ink.r, cov.ink.g, cov.ink.b, 0.1)) }
            GradientStop { position: 1; color: Qt.tint(palette.window, Qt.rgba(cov.ink.r, cov.ink.g, cov.ink.b, 0.05)) }
        }
        IdleText {
            anchors.centerIn: parent
            text: "♪"
            color: Qt.rgba(cov.ink.r, cov.ink.g, cov.ink.b, 0.22)
            size: cov.height * 0.34
            weight: 300
        }
    }
    MultiEffect {
        id: fx
        anchors.fill: parent
        source: img
        visible: cov.ready
        maskEnabled: true
        maskSource: mask
    }
    // a hairline inside the edge keeps dark artwork apart from a dark background (and light from light)
    Rectangle {
        anchors.fill: parent
        visible: cov.edge
        radius: cov.radius
        color: "transparent"
        border.color: Qt.rgba(cov.ink.r, cov.ink.g, cov.ink.b, 0.08)
        border.width: 1
        antialiasing: true
    }
    NumberAnimation { id: fade; target: fx; property: "opacity"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
}
