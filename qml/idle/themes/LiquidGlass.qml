import QtQuick

// A pane of liquid glass (shaders/glass.frag): a rounded rectangle whose rim is a convex bevel. The backdrop
// (`source`) is refracted through the rim with Snell's law, one index of refraction per color channel so the edge
// splits into a faint spectrum; the flat middle shows the backdrop undistorted under a `tint`. The rim catches a
// highlight from `lightAngle` and a weaker internal reflection on the opposite side, and the pane casts its own soft
// shadow. Static glass maps itself onto the source after it is laid out and again when the window or the pane
// changes size; set `follow` for glass that moves.
Item {
    id: root

    property GlassSource source
    property real radius: Math.min(width, height) / 2

    property real bezel: 16
    property real thickness: 18
    property real ior: 1.5
    property real dispersion: 0.03
    property real magnify: 1.0
    property real frost: 0
    property real clearRim: 0       // 1: the rim stays clear while the middle is frosted
    property color tint: "transparent"
    property real saturation: 1.1
    property real brightness: 1.0
    property real rimLight: 0.6
    property real lightAngle: -135
    property real shadowOpacity: 0.2
    property real shadowRadius: 24
    property real shadowOffset: 6
    property bool follow: false
    property point glowPos           // a soft light under the pointer (pressed buttons)
    property real glow: 0
    property real glowRadius: 50

    readonly property real _margin: Math.ceil(shadowRadius + shadowOffset + 2)

    ShaderEffect {
        id: fx

        x: -root._margin
        y: -root._margin
        width: root.width + 2 * root._margin
        height: root.height + 2 * root._margin
        fragmentShader: "shaders/glass.frag.qsb"

        property var source: root.source ? root.source.texture : null
        property var sourceBlur: root.source ? root.source.blurredTexture : null

        property size itemSize: Qt.size(width, height)
        property vector4d srcMap: Qt.vector4d(0, 0, 1, 1)
        property point srcScale: Qt.point(1, 1)
        property vector4d shape0: Qt.vector4d(root._margin, root._margin, root.width, root.height)
        property vector4d shape1: Qt.vector4d(0, 0, 0, 0)
        property vector4d shape2: Qt.vector4d(0, 0, 0, 0)
        property vector4d shape3: Qt.vector4d(0, 0, 0, 0)
        property vector4d radii: Qt.vector4d(Math.min(root.radius, root.width / 2, root.height / 2), 0, 0, 0)
        property real shapeCount: 1
        property real smoothing: 0
        property real bezel: Math.max(1, Math.min(root.bezel, Math.min(root.width, root.height) / 2 - 0.5))
        property real thickness: root.thickness
        property real ior: root.ior
        property real dispersion: root.dispersion
        property real magnify: root.magnify
        property real frost: root.frost
        property real clearRim: root.clearRim
        property color tint: root.tint
        property real saturation: root.saturation
        property real brightness: root.brightness
        property real rimLight: root.rimLight
        property real lightAngle: root.lightAngle * Math.PI / 180
        property real shadowOpacity: root.shadowOpacity
        property real shadowRadius: root.shadowRadius
        property real shadowOffset: root.shadowOffset
        property point glowPos: Qt.point(root.glowPos.x + root._margin, root.glowPos.y + root._margin)
        property real glow: root.glow
        property real glowRadius: root.glowRadius

        // where this effect's pixels lie in the source texture (origin and scale), so the backdrop lines up
        function updateMapping() {
            const it = root.source ? root.source.sourceItem : null
            if (!it)
                return
            const o = mapToItem(it, 0, 0)
            const ox = mapToItem(it, 100, 0)
            const oy = mapToItem(it, 0, 100)
            const pad = root.source.padding
            const m = Qt.vector4d(o.x + pad, o.y + pad, it.width + 2 * pad, it.height + 2 * pad)
            const s = Qt.point((ox.x - o.x) / 100, (oy.y - o.y) / 100)
            if (!m.fuzzyEquals(srcMap, 0.01))
                srcMap = m
            if (Math.abs(s.x - srcScale.x) > 1e-4 || Math.abs(s.y - srcScale.y) > 1e-4)
                srcScale = s
        }

        // every frame while following, otherwise for a few frames after a change of size or place (positioners
        // and the stage settle a frame or two later than the change itself)
        property int settle: 30
        function resettle() { settle = 30 }
        FrameAnimation {
            running: (root.follow || fx.settle > 0) && root.visible && root.source !== null
            onTriggered: {
                fx.updateMapping()
                if (fx.settle > 0)
                    fx.settle--
            }
        }
        onWidthChanged: resettle()
        onHeightChanged: resettle()
    }
    Connections {
        target: root.Window.window
        function onWidthChanged() { fx.resettle() }
        function onHeightChanged() { fx.resettle() }
    }
    onVisibleChanged: fx.resettle()
}
