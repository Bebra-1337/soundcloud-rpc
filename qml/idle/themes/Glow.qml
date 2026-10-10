import QtQuick
import QtQuick.Shapes

// A soft round light: a radial gradient from `color` at `strength` in the middle to nothing at the edge. Smooth at any
// size (a blurred disc shows its edge when it is large). `rim` gives the brighter, crisp-edged disc a lens makes of
// an out-of-focus point of light (bokeh).
Shape {
    id: g
    property color color: palette.accent
    property real strength: 0.2
    property bool rim: false

    preferredRendererType: Shape.GeometryRenderer
    ShapePath {
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: g.width / 2; centerY: g.height / 2; centerRadius: Math.min(g.width, g.height) / 2
            focalX: centerX; focalY: centerY
            GradientStop { position: 0.0; color: Qt.rgba(g.color.r, g.color.g, g.color.b, g.strength * (g.rim ? 0.55 : 1)) }
            GradientStop { position: g.rim ? 0.78 : 0.35; color: Qt.rgba(g.color.r, g.color.g, g.color.b, g.strength * (g.rim ? 0.7 : 0.55)) }
            GradientStop { position: g.rim ? 0.92 : 0.7; color: Qt.rgba(g.color.r, g.color.g, g.color.b, g.strength * (g.rim ? 1 : 0.15)) }
            GradientStop { position: 1.0; color: Qt.rgba(g.color.r, g.color.g, g.color.b, 0) }
        }
        startX: 0; startY: 0
        PathLine { x: g.width; y: 0 }
        PathLine { x: g.width; y: g.height }
        PathLine { x: 0; y: g.height }
        PathLine { x: 0; y: 0 }
    }
}
