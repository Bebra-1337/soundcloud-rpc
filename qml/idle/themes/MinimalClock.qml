import QtQuick

// Minimal: the track's title set large is its progress bar. The part already played is filled with the text color,
// the rest stays faint, a fine accent mark sits on the edge; a click or a drag on the title seeks. A large cover on
// the left; beside it a column on the cover's top and bottom edges: the title, the artist and the times under it,
// the controls at the foot.
ThemeBase {
    id: root

    background: [
        Rectangle { anchors.fill: parent; color: root.bg }
    ]

    // the title as a progress bar: faint underneath, filled on top and cut at the played fraction
    component FillTitle: Item {
        id: line
        property real titleSize: 27
        property int align: Text.AlignLeft
        height: titleSize * 1.24 * root.u
        readonly property real shown: seek.pressed ? seek.value : root.progress
        readonly property real textWidth: Math.min(width, faint.contentWidth)
        // where the painted text starts inside the line (it is centred for a centred title)
        readonly property real textX: align === Text.AlignHCenter ? (width - textWidth) / 2 : 0

        IdleText {
            id: faint
            width: parent.width; height: parent.height
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: line.align
            text: root.title || qsTr("Nothing playing")
            size: line.titleSize * root.u
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Math.round(11 * root.u)
            weight: 650
            tracking: -0.04
            maximumLineCount: 1
            elide: Text.ElideRight
            color: root.alpha(root.ink, root.light ? 0.13 : 0.16)
        }
        Item {
            x: line.textX
            width: line.textWidth * line.shown
            height: parent.height
            clip: true
            Behavior on width { enabled: !seek.pressed; NumberAnimation { duration: 250 } }
            IdleText {
                x: -line.textX
                width: line.width; height: line.height
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: line.align
                text: faint.text
                size: faint.size
                fontSizeMode: faint.fontSizeMode
                minimumPixelSize: faint.minimumPixelSize
                weight: faint.weight
                tracking: faint.tracking
                maximumLineCount: 1
                elide: Text.ElideRight
                color: root.ink
            }
        }
        Rectangle {
            x: Math.round(line.textX + line.textWidth * line.shown) - width / 2
            height: Math.min(line.height, faint.contentHeight) * 0.74
            y: (line.height - height) / 2
            width: Math.max(2, 0.6 * root.u)
            radius: width / 2
            color: root.playing || seek.pressed ? root.accent : root.alpha(root.ink, 0.35)
            Behavior on x { enabled: !seek.pressed; NumberAnimation { duration: 250 } }
        }
        MouseArea {
            id: seek
            property real value: 0
            x: line.textX; width: line.textWidth; height: parent.height
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.max(0, Math.min(1, x / width)) }
            onPressed: (e) => value = at(e.x)
            onPositionChanged: (e) => { if (pressed) value = at(e.x) }
            onReleased: (e) => root.requestSeek(at(e.x) * root.duration)
        }
    }

    Cover {
        x: 14 * root.u; y: 14 * root.u
        width: 72 * root.u; height: width; radius: 1.4 * root.u
        source: root.cover; shadowStrength: 0.8
    }
    FillTitle {
        id: title
        x: 99 * root.u; y: 11 * root.u
        width: 173 * root.u
        titleSize: 26
    }
    IdleText {
        id: artistLine
        x: 100 * root.u; y: title.y + title.height + 1 * root.u
        width: 120 * root.u
        text: root.artist
        serif: true; font.italic: true
        size: 9 * root.u
        color: root.alpha(root.ink, 0.65)
        elide: Text.ElideRight
    }
    IdleText {
        x: 272 * root.u - width
        anchors.baseline: artistLine.baseline
        //: shown before the elapsed time while the music is paused
        text: (root.playing ? "" : qsTr("Paused") + "  ·  ") + root.elapsedText + " / " + root.fmt(root.duration)
        color: root.alpha(root.ink, 0.5)
        size: 3 * root.u; weight: 500; tracking: 0.02; tabular: true
    }
    Controls {
        x: 100 * root.u; y: 86 * root.u - height
        width: 172 * root.u
        unit: root.u
        theme: root
    }
}
