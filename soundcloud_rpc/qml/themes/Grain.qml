import QtQuick

// Static film grain; painted once per size.
Canvas {
    id: g
    property real amount: 0.09
    anchors.fill: parent
    opacity: amount
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d")
        c.reset()
        var n = Math.min(22000, width * height / 40)
        for (var i = 0; i < n; i++) {
            c.fillStyle = Math.random() < 0.5 ? "rgba(255,255,255,0.6)" : "rgba(0,0,0,0.7)"
            c.fillRect(Math.random() * width, Math.random() * height, 1.4, 1.4)
        }
    }
}
