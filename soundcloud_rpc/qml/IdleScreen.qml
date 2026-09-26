import QtQuick

// Host for the idle themes: Python sets these properties, the selected theme scene only draws them.
Item {
    id: host

    property string theme: "GlassCard"
    property bool active: false
    property string title: ""
    property string artist: ""
    property url cover: ""
    property real syncPosition: 0  // last position reported by the site (whole seconds, irregular phase)
    property real position: 0      // smooth position shown by the themes
    property real duration: 1
    property bool playing: true

    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 700 } }

    Rectangle { anchors.fill: parent; color: "#111111" }

    // The site reports whole seconds with an irregular phase. Following every report makes the bar and the
    // digits jump back and forth (0:23, 0:21, 0:22), so the position is extrapolated from an anchor and only
    // re-anchored when the report disagrees with it by more than a second and a half (seek, new track).
    property double anchorMs: 0
    property real anchorPos: 0
    function reanchor(p) {
        anchorPos = p
        anchorMs = Date.now()
        position = Math.min(duration, p)
    }
    onSyncPositionChanged: {
        if (!playing || Math.abs(syncPosition + 0.5 - position) > 1.6)
            reanchor(syncPosition)
    }
    onPlayingChanged: reanchor(playing ? position : syncPosition)
    onActiveChanged: if (active) reanchor(syncPosition)
    Timer {
        interval: 200; repeat: true; running: host.active && host.playing
        onTriggered: host.position = Math.min(host.duration, host.anchorPos + (Date.now() - host.anchorMs) / 1000)
    }

    // Unloaded while inactive, so hidden themes cost no rendering or animation time.
    Loader {
        id: ld
        anchors.fill: parent
        active: host.active
        source: "themes/" + host.theme + ".qml"
    }
    Binding { target: ld.item; property: "title"; value: host.title; when: ld.item }
    Binding { target: ld.item; property: "artist"; value: host.artist; when: ld.item }
    Binding { target: ld.item; property: "cover"; value: host.cover; when: ld.item }
    Binding { target: ld.item; property: "position"; value: host.position; when: ld.item }
    Binding { target: ld.item; property: "duration"; value: host.duration; when: ld.item }
    Binding { target: ld.item; property: "playing"; value: host.playing; when: ld.item }
}
