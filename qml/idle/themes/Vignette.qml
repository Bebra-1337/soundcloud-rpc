import QtQuick

// Darkens the edges (elliptical enough for wide windows): four edge gradients.
Item {
    id: v
    property real strength: 0.6
    property real reach: 0.3
    anchors.fill: parent

    readonly property color edge: Qt.rgba(0, 0, 0, strength)
    readonly property color clear: Qt.rgba(0, 0, 0, 0)

    Rectangle {
        width: v.width * v.reach * 0.6; height: v.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: v.edge }
            GradientStop { position: 1; color: v.clear }
        }
    }
    Rectangle {
        x: v.width - width
        width: v.width * v.reach * 0.6; height: v.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: v.clear }
            GradientStop { position: 1; color: v.edge }
        }
    }
    Rectangle {
        width: v.width; height: v.height * v.reach
        gradient: Gradient {
            GradientStop { position: 0; color: v.edge }
            GradientStop { position: 1; color: v.clear }
        }
    }
    Rectangle {
        y: v.height - height
        width: v.width; height: v.height * v.reach
        gradient: Gradient {
            GradientStop { position: 0; color: v.clear }
            GradientStop { position: 1; color: v.edge }
        }
    }
}
