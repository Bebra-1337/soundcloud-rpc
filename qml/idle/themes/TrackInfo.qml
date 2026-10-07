import QtQuick

// Eyebrow, title (up to two lines), artist and progress: the shared text block of every theme.
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
    property real titleSize: 8.4
    property bool showEyebrow: true
    property bool showProgress: true
    property color ink: "#f2f2f2"
    property color inkDim: "#a3a3a3"

    spacing: unit * 1.1

    NowPlaying {
        visible: info.showEyebrow
        width: info.width
        unit: info.unit
        playing: info.playing
        align: info.align
        color: info.inkDim
    }
    Text {
        width: info.width
        text: info.title || "Nothing playing"
        color: info.ink
        font.pixelSize: info.unit * info.titleSize
        font.weight: Font.DemiBold
        font.letterSpacing: -info.unit * 0.12
        lineHeight: 0.95
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        horizontalAlignment: info.align
    }
    Text {
        width: info.width
        visible: text !== ""
        text: info.artist
        color: info.inkDim
        font.pixelSize: info.unit * info.titleSize * 0.55
        elide: Text.ElideRight
        horizontalAlignment: info.align
    }
    Item { width: 1; height: info.unit * 1.2; visible: info.showProgress }
    Progress {
        visible: info.showProgress
        width: info.width
        unit: info.unit
        value: info.progress
        leftText: info.elapsedText
        rightText: info.remainingText
        color: info.ink
    }
}
