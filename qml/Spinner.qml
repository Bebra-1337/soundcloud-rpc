import QtQuick
import QtQuick.Shapes

// Rotating arc, used for loading states.
Item {
    id: spinner

    property color color: Style.ink
    property real lineWidth: 2.5
    property bool running: visible

    implicitWidth: 28
    implicitHeight: 28

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        RotationAnimation on rotation {
            running: spinner.running
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }
        ShapePath {
            strokeColor: spinner.color
            strokeWidth: spinner.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: spinner.width / 2
                centerY: spinner.height / 2
                radiusX: spinner.width / 2 - spinner.lineWidth
                radiusY: spinner.height / 2 - spinner.lineWidth
                startAngle: 0
                sweepAngle: 270
            }
        }
    }
}
