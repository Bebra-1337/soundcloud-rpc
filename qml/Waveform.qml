import QtQuick
import ScBackend

// SoundCloud-style waveform seek bar. The played part is the same bars drawn in ink and clipped to the
// progress, so only one clip width changes while playing.
Item {
    id: wf

    readonly property var samples: Player.waveform.length > 0 ? Player.waveform : flat
    readonly property var flat: Array(80).fill(0.35)
    readonly property real progress: Player.duration > 0 ? Math.min(1, Player.position / Player.duration) : 0
    property real dragProgress: -1
    readonly property real shown: dragProgress >= 0 ? dragProgress : progress

    component Bars: Row {
        id: bars
        property var samples: []
        property color barColor
        property real fullHeight
        spacing: 1
        Repeater {
            model: bars.samples.length
            Rectangle {
                required property int index
                width: Math.max(1, (bars.width - (bars.samples.length - 1) * bars.spacing) / bars.samples.length)
                height: Math.max(2, bars.samples[index] * bars.fullHeight)
                y: (bars.fullHeight - height) / 2
                radius: width / 2
                color: bars.barColor
            }
        }
    }

    Bars {
        width: wf.width
        height: wf.height
        samples: wf.samples
        fullHeight: wf.height
        barColor: Style.outline
    }
    Item {
        width: wf.width * wf.shown
        height: wf.height
        clip: true
        Bars {
            width: wf.width
            height: wf.height
            samples: wf.samples
            fullHeight: wf.height
            barColor: Style.accent
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
