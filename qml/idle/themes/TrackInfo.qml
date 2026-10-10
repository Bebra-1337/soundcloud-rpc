import QtQuick

// Title (up to two lines), artist and progress: the shared text block of the themes. Display-cut Inter, tight
// tracking on the title, generous space before the progress line.
Column {
    id: info
    property real unit: 5
    property string title
    property string artist
    property real progress
    property string elapsedText
    property string remainingText
    property bool playing: true
    property int align: Text.AlignLeft
    property real titleSize: 9
    property int titleLines: 2
    property real titleWeight: 640
    property bool serif: false
    property string eyebrow: ""
    property bool showProgress: true
    property bool pausedLabel: true
    property Item theme: null                 // set: the progress seeks and the controls show under it
    property bool showControls: theme !== null
    property bool compactControls: false
    property bool glass: false                // glass controls and progress groove
    property GlassSource glassSource: null    // set: the buttons are liquid glass refracting it
    property color ink: palette.windowText
    property color inkDim: Qt.rgba(ink.r, ink.g, ink.b, 0.62)

    spacing: 0

    IdleText {
        visible: text !== ""
        width: info.width
        text: info.eyebrow
        color: info.inkDim
        size: info.unit * 2.4
        font.capitalization: Font.AllUppercase
        weight: 600
        tracking: 0.14
        horizontalAlignment: info.align
        bottomPadding: info.unit * 2.4
    }
    IdleText {
        width: info.width
        text: info.title || qsTr("Nothing playing")
        color: info.ink
        serif: info.serif
        size: info.unit * info.titleSize
        weight: info.titleWeight
        tracking: info.serif ? -0.01 : -0.028
        lineHeight: info.serif ? 0.92 : 0.98
        wrapMode: Text.WordWrap
        maximumLineCount: info.titleLines
        elide: Text.ElideRight
        horizontalAlignment: info.align
    }
    IdleText {
        width: info.width
        visible: text !== ""
        topPadding: info.unit * 1.3
        text: info.artist
        color: info.inkDim
        size: info.unit * Math.max(4, info.titleSize * 0.44)
        weight: 450
        tracking: -0.005
        elide: Text.ElideRight
        horizontalAlignment: info.align
    }
    Item { width: 1; height: info.unit * 6.5; visible: info.showProgress }
    Progress {
        visible: info.showProgress
        width: info.width
        unit: info.unit
        value: info.progress
        playing: info.playing
        pausedLabel: info.pausedLabel
        theme: info.theme
        glass: info.glass
        liquid: info.glassSource !== null
        leftText: info.elapsedText
        rightText: info.remainingText
    }
    Item { width: 1; height: info.unit * 1.2; visible: info.showControls }
    Controls {
        visible: info.showControls
        width: info.width
        unit: info.unit
        theme: info.theme
        compact: info.compactControls
        glass: info.glass
        glassSource: info.glassSource
        align: info.align === Text.AlignRight ? Qt.AlignRight : (info.align === Text.AlignHCenter ? Qt.AlignHCenter : Qt.AlignLeft)
    }
}
