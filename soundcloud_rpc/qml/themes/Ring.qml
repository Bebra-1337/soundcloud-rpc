import QtQuick

// Circular/elliptical progress ring. half: 0 = whole, 1 = lower half only, -1 = upper half only.
Canvas {
    id: ring
    property real value: 0
    property color color: "white"
    property color trackColor: "#22ffffff"
    property real lineWidth: 4
    property real ratio: 1
    property int half: 0
    property bool showTrack: true

    onValueChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var c = getContext("2d")
        c.reset()
        var cx = width / 2, cy = height / 2
        var rx = width / 2 - lineWidth, ry = rx * ratio
        if (half !== 0) {
            c.beginPath()
            c.rect(0, half > 0 ? cy : 0, width, height / 2)
            c.clip()
        }
        c.lineWidth = lineWidth
        c.lineCap = "round"
        if (showTrack) {
            c.strokeStyle = trackColor
            c.beginPath()
            c.ellipse(cx - rx, cy - ry, rx * 2, ry * 2)
            c.stroke()
        }
        if (value > 0) {
            c.strokeStyle = color
            c.beginPath()
            var steps = Math.max(2, Math.floor(180 * value))
            for (var i = 0; i <= steps; i++) {
                var a = -Math.PI / 2 + Math.PI * 2 * value * i / steps
                var x = cx + rx * Math.cos(a), y = cy + ry * Math.sin(a)
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
            }
            c.stroke()
        }
    }
}
