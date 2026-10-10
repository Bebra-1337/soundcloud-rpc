import QtQuick
import QtQuick.Effects

// Full-bleed color field made of the cover: two heavily blurred copies turn slowly against each other, so the
// cover's colors drift into one another like a lit room rather than sitting as a smudge, and fade between tracks.
// A veil of the background color on top sets how deep (dark schemes) or pastel (light schemes) it gets.
// MultiEffect measures the blur radius in pixels of the item it is applied to, so each copy is blurred at 1/shrink
// of its size and scaled up: the blur ends up very wide, and it is cheap.
Item {
    id: bd
    property url source
    property real veil: 0.55        // how much of the background color covers the field
    property real saturation: 0.1
    property real contrast: 0.0
    property real brightness: 0.0
    property bool animated: true
    property int detail: 16         // pixels the cover is sampled at: more keeps its shapes under the blur
    property int blurMax: 32
    property int copies: 2
    readonly property real shrink: 8
    readonly property real side: Math.ceil(Math.sqrt(width * width + height * height) * 1.15)

    Rectangle { anchors.fill: parent; color: palette.window }

    Item {
        anchors.fill: parent
        opacity: img.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1200 } }

        Repeater {
            model: bd.copies
            Item {
                id: layerItem
                width: bd.side; height: bd.side
                x: (bd.width - width) / 2; y: (bd.height - height) / 2
                opacity: index === 0 ? 1 : 0.55
                RotationAnimator on rotation {
                    from: index === 0 ? 0 : 360; to: index === 0 ? 360 : 0
                    duration: index === 0 ? 150000 : 110000
                    loops: Animation.Infinite
                    running: bd.animated
                }
                Item {
                    width: parent.width / bd.shrink
                    height: parent.height / bd.shrink
                    scale: bd.shrink
                    transformOrigin: Item.TopLeft
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: bd.blurMax
                        saturation: bd.saturation
                        contrast: bd.contrast
                        brightness: bd.brightness
                    }
                    Image {
                        anchors.fill: parent
                        source: bd.source
                        sourceSize.width: bd.detail
                        sourceSize.height: bd.detail
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mirror: index === 1
                        rotation: index === 1 ? 180 : 0
                    }
                }
            }
        }
        Image { id: img; visible: false; source: bd.source; sourceSize.width: 16; sourceSize.height: 16; asynchronous: true }
    }
    Rectangle { anchors.fill: parent; color: palette.window; opacity: bd.veil }
}
