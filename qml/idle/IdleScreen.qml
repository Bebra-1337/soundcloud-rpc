import QtQuick

// Host for the idle themes: the app sets these properties, the selected theme scene only draws them.
Item {
    id: host

    property string theme: "GlassCard"
    property bool active: false
    property string title: ""
    property string artist: ""
    property url cover: ""
    property real syncPosition: 0  // player position in seconds, reported a few times a second
    property real position: 0      // smooth position shown by the themes
    property real duration: 1
    property bool playing: true
    property real audioBass: 0
    property real audioMid: 0
    property real audioTreble: 0
    property real audioLevel: 0
    property var audioBands: []
    property var audioBandsL: []
    property var audioBandsR: []

    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 700 } }

    Rectangle { anchors.fill: parent; color: "#111111" }

    // Between the player's reports the position is extrapolated from the last one, so bars and digits move
    // smoothly whatever the report rate is.
    property double anchorMs: 0
    property real anchorPos: 0
    function reanchor(p) {
        anchorPos = p
        anchorMs = Date.now()
        position = Math.min(duration, p)
    }
    onSyncPositionChanged: reanchor(syncPosition)
    onPlayingChanged: reanchor(syncPosition)
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
    Binding { target: ld.item; property: "audioBands"; value: host.audioBands; when: ld.item }
    Binding { target: ld.item; property: "audioBandsL"; value: host.audioBandsL; when: ld.item }
    Binding { target: ld.item; property: "audioBandsR"; value: host.audioBandsR; when: ld.item }
    // audioLevel is bound last: the theme feeds its reactor when it changes, after the other bands are in
    Binding { target: ld.item; property: "audioBass"; value: host.audioBass; when: ld.item }
    Binding { target: ld.item; property: "audioMid"; value: host.audioMid; when: ld.item }
    Binding { target: ld.item; property: "audioTreble"; value: host.audioTreble; when: ld.item }
    Binding { target: ld.item; property: "audioLevel"; value: host.audioLevel; when: ld.item }
}
