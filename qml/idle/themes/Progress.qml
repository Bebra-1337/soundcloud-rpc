import QtQuick

// Progress line with elapsed / remaining underneath. The played part is the accent; paused, it falls back to a
// quiet tone and the elapsed label says so. With a `theme` it seeks: under the pointer the line thickens and shows
// a knob, a drag moves the knob (and the elapsed label) and the seek happens on release.
Item {
    id: p
    property real unit: 5
    property real value: 0
    property string leftText: ""
    property string rightText: ""
    property bool playing: true
    property color color: palette.accent
    property color track: Qt.rgba(palette.windowText.r, palette.windowText.g, palette.windowText.b, 0.13)
    property color labelColor: Qt.rgba(palette.windowText.r, palette.windowText.g, palette.windowText.b, 0.55)
    property real thickness: unit * 0.55
    property bool labels: true
    property bool pausedLabel: true   // off where the theme shows the paused state elsewhere
    property Item theme: null         // set: click or drag to seek
    property bool glass: false        // the line as a groove cut into glass
    property bool liquid: false       // the knob as a pill of liquid glass that magnifies the line while dragged

    readonly property bool scrubbing: seekArea.pressed
    property real scrubValue: 0
    readonly property real shown: scrubbing ? scrubValue : value
    readonly property real hot: theme && (seekArea.containsMouse || seekArea.pressed) ? 1 : 0

    height: labels ? thickness + unit * 5.2 : thickness

    Rectangle {
        id: bar
        width: p.width
        height: p.thickness * ((p.glass ? 1.6 : 1) + 0.6 * p.hot)
        y: (p.thickness - height) / 2
        radius: height / 2
        color: p.glass ? Qt.rgba(0, 0, 0, 0.16) : p.track
        border.width: p.glass ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.22)
        Behavior on height { NumberAnimation { duration: 120 } }
        Rectangle {
            width: Math.max(height, parent.width * p.shown)
            height: parent.height
            radius: height / 2
            color: p.playing ? p.color : Qt.rgba(p.labelColor.r, p.labelColor.g, p.labelColor.b, 0.8)
            Behavior on width { enabled: !p.scrubbing; NumberAnimation { duration: 250 } }
            Behavior on color { ColorAnimation { duration: 400 } }
        }
    }
    IdleText {
        visible: p.labels
        y: p.thickness + p.unit * 1.8
        //: shown before the elapsed time while the music is paused
        text: p.scrubbing && p.theme ? p.theme.fmt(p.scrubValue * p.theme.duration)
              : (p.playing || !p.pausedLabel || !p.leftText ? p.leftText : qsTr("Paused") + "  ·  " + p.leftText)
        color: p.labelColor
        size: p.unit * 2.6
        weight: 500
        tracking: 0.02
        tabular: true
    }
    IdleText {
        visible: p.labels
        y: p.thickness + p.unit * 1.8
        x: p.width - width
        text: p.rightText
        color: p.labelColor
        size: p.unit * 2.6
        weight: 500
        tracking: 0.02
        tabular: true
    }
    Rectangle {
        visible: p.hot > 0 && !p.liquid
        width: p.unit * 2.2; height: width; radius: width / 2
        x: p.width * p.shown - width / 2
        y: p.thickness / 2 - height / 2
        color: palette.windowText
    }
    Loader {
        active: p.liquid
        sourceComponent: Item {
            GlassSource { id: barSource; sourceItem: bar; padding: p.unit * 6 }
            GlassKnob {
                source: barSource
                width: p.unit * 3.6; height: p.unit * 2.3
                x: p.width * p.shown - width / 2
                y: p.thickness / 2 - height / 2
                active: p.scrubbing
                opacity: p.hot
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
        }
    }
    // a generous hit area around the thin line
    MouseArea {
        id: seekArea
        enabled: p.theme !== null
        x: 0; y: -p.unit * 2.5
        width: p.width; height: p.thickness + p.unit * 5
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function at(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: (e) => p.scrubValue = at(e.x)
        onPositionChanged: (e) => { if (pressed) p.scrubValue = at(e.x) }
        onReleased: (e) => p.theme.requestSeek(at(e.x) * p.theme.duration)
    }
}
