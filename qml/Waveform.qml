import QtQuick
import ScBackend

// SoundCloud-style waveform seek bar. Each bar takes the accent color as the progress passes it, the bar under
// the progress edge in between by the fraction already played: a clip would only move in whole pixels, which on a
// ~310 px bar and a 5 minute track is one visible step a second.
Item {
    id: wf

    readonly property var samples: Player.waveform.length > 0 ? Player.waveform : flat
    readonly property var flat: Array(80).fill(0.35)
    readonly property real progress: Player.duration > 0 ? Math.min(1, Player.position / Player.duration) : 0
    property real dragProgress: -1
    readonly property real shown: dragProgress >= 0 ? dragProgress : progress

    Row {
        id: bars
        width: wf.width
        height: wf.height
        spacing: 1
        readonly property real barWidth: Math.max(1, (width - (wf.samples.length - 1) * spacing) / wf.samples.length)
        readonly property real playedX: wf.shown * width

        Repeater {
            model: wf.samples.length
            Rectangle {
                required property int index
                readonly property real played: Math.max(0, Math.min(1, (bars.playedX - index * (bars.barWidth + bars.spacing)) / bars.barWidth))
                width: bars.barWidth
                height: Math.max(2, wf.samples[index] * wf.height)
                y: (wf.height - height) / 2
                radius: width / 2
                color: played <= 0 ? Style.outline : (played >= 1 ? Style.accent : Style.mix(Style.outline, Style.accent, played))
            }
        }
    }
    Rectangle {
        visible: ma.containsMouse && wf.dragProgress < 0
        x: Math.round(ma.mouseX)
        width: 1
        height: wf.height
        color: Style.inkDim
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: Player.hasTrack
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function at(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: (mouse) => wf.dragProgress = at(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) wf.dragProgress = at(mouse.x) }
        onReleased: (mouse) => {
            Player.seek(at(mouse.x) * Player.duration)
            wf.dragProgress = -1
        }
        onCanceled: wf.dragProgress = -1
    }
}
