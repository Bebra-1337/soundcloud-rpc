import QtQuick

// Text of the idle themes. Sans is Inter (variable: `weight` 100..900 and the optical size, which follows the pixel
// size from text (14) to display (32) cuts, go through the font axes); `serif` is Cormorant Garamond (one weight,
// roman and italic). `size` is the pixel size (set it instead of font.pixelSize, which the axes and the tracking
// cannot read without a binding loop), `tracking` letter spacing in em, `tabular` digits of equal width (times).
Text {
    id: t
    property real size: 14
    property real weight: 400
    property bool serif: false
    property real tracking: 0
    property bool tabular: false

    font.pixelSize: size
    font.family: serif ? "Cormorant Garamond" : "Inter Variable"
    font.variableAxes: serif ? ({}) : ({ "wght": weight, "opsz": Math.max(14, Math.min(32, size)) })
    font.letterSpacing: tracking * size
    font.features: tabular ? ({ "tnum": 1 }) : ({})
    color: palette.windowText
}
