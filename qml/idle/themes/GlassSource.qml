import QtQuick
import QtQuick.Effects

// What a LiquidGlass refracts: a live texture of `sourceItem` (the theme's backdrop) and, with `blurEnabled`, a
// blurred copy for frosted glass. The glass must not be inside `sourceItem`, or it would refract itself. A backdrop
// that only drifts slowly can be captured `fps` times a second instead of every frame (0: every frame), which
// saves the passes at high refresh rates.
Item {
    id: root

    property Item sourceItem
    property real padding: 0          // transparent margin around the item, for glass that overhangs it (a knob)
    property real blurRadius: 28
    property bool blurEnabled: false
    property int fps: 0

    readonly property ShaderEffectSource texture: sharp
    readonly property Item blurredTexture: blurEnabled ? blurred : sharp

    ShaderEffectSource {
        id: sharp
        visible: false
        sourceItem: root.sourceItem
        width: (root.sourceItem ? root.sourceItem.width : 0) + 2 * root.padding
        height: (root.sourceItem ? root.sourceItem.height : 0) + 2 * root.padding
        sourceRect: root.padding > 0 ? Qt.rect(-root.padding, -root.padding, width, height) : Qt.rect(0, 0, 0, 0)
        live: root.fps <= 0
    }

    MultiEffect {
        id: blurEffect
        visible: false
        width: sharp.width
        height: sharp.height
        source: sharp
        blurEnabled: root.blurEnabled
        blur: 1.0
        blurMax: Math.round(root.blurRadius)
        autoPaddingEnabled: false
    }

    ShaderEffectSource {
        id: blurred
        visible: false
        sourceItem: root.blurEnabled ? blurEffect : null
        width: sharp.width
        height: sharp.height
        live: root.fps <= 0
    }

    Timer {
        interval: 1000 / Math.max(1, root.fps)
        repeat: true
        running: root.fps > 0 && root.visible
        onTriggered: {
            sharp.scheduleUpdate()
            if (root.blurEnabled)
                blurred.scheduleUpdate()
        }
    }
}
