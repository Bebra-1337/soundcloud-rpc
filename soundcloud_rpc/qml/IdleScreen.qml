import QtQuick

// Host for the idle themes: Python sets these properties, the selected theme scene only draws them.
Item {
    id: host

    property string theme: "GlassCard"
    property bool active: false
    property string title: ""
    property string artist: ""
    property url cover: ""
    property real position: 0
    property real duration: 1
    property bool playing: true

    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 700 } }

    Rectangle { anchors.fill: parent; color: "#111111" }

    // Python refreshes position about once a second; tick locally in between so the timer is smooth.
    Timer {
        interval: 1000; repeat: true; running: host.active && host.playing
        onTriggered: host.position = Math.min(host.duration, host.position + 1)
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
