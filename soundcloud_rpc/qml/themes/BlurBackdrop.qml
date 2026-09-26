import QtQuick
import QtQuick.Effects

// Full-bleed, heavily blurred version of the cover; slowly breathes (Ken Burns) and fades between tracks.
// MultiEffect measures the blur radius in pixels of the item it is applied to, so the effect runs on a
// small item that is scaled up: the blur ends up very wide, and it is cheap.
Item {
    id: bd
    property url source
    property real brightness: -0.25
    property real saturation: -1.0
    property real contrast: 0.0
    property real zoom: 1.3
    readonly property real shrink: 7

    Rectangle { anchors.fill: parent; color: "#111111" }
    Item {
        id: holder
        anchors.fill: parent
        opacity: img.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 900 } }
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { from: bd.zoom; to: bd.zoom * 1.08; duration: 38000; easing.type: Easing.InOutSine }
            NumberAnimation { from: bd.zoom * 1.08; to: bd.zoom; duration: 38000; easing.type: Easing.InOutSine }
        }
        Item {
            width: holder.width / bd.shrink
            height: holder.height / bd.shrink
            scale: bd.shrink
            transformOrigin: Item.TopLeft
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 32
                brightness: bd.brightness
                saturation: bd.saturation
                contrast: bd.contrast
            }
            Image {
                id: img
                anchors.fill: parent
                source: bd.source
                sourceSize.width: 14
                sourceSize.height: 14
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
    }
}
