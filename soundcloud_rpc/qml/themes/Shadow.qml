import QtQuick
import QtQuick.Effects

// Soft drop shadow for a rounded rectangle of the item's size.
Item {
    id: sh
    property real radius: 0
    property real offsetY: 0
    property real strength: 0.5
    property real blurMax: 64

    Rectangle { id: src; anchors.fill: parent; radius: sh.radius; color: "black"; visible: false; layer.enabled: true }
    MultiEffect {
        source: src
        x: 0; y: sh.offsetY; width: sh.width; height: sh.height
        blurEnabled: true; blur: 1.0; blurMax: sh.blurMax
        opacity: sh.strength
    }
}
