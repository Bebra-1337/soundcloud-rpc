import QtQuick

// The player's controls for every idle theme: like, shuffle, previous, play/pause, next, repeat and volume.
// Bound to a theme (`theme`), which carries the player's state and passes the requests to the app. `compact`
// leaves out the volume slider (the speaker still mutes) for narrow columns; `transport: false` leaves out
// previous / play / next, for a theme that has its own (the cassette deck's keys). `align` places the row.
Item {
    id: c
    property Item theme
    property real unit: 5
    property bool compact: false
    property bool transport: true
    property bool glass: false        // frosted-glass buttons, for glass themes
    property GlassSource glassSource: null   // with `glass`: liquid glass buttons refracting it
    property int align: Qt.AlignLeft

    implicitHeight: 11 * unit
    height: implicitHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: c.align === Qt.AlignRight ? c.width - width : (c.align === Qt.AlignHCenter ? (c.width - width) / 2 : -1.6 * c.unit)
        spacing: (c.glass ? 1.6 : 0.4) * c.unit   // glass discs need air between them

        IdleButton {
            anchors.verticalCenter: parent.verticalCenter
            unit: c.unit; glass: c.glass; glassSource: c.glassSource; icon: "heart"
            active: c.theme && c.theme.liked; filled: active
            onClicked: c.theme.requestLike()
        }
        Item { width: 1.6 * c.unit; height: 1 }
        IdleButton {
            anchors.verticalCenter: parent.verticalCenter
            unit: c.unit; glass: c.glass; glassSource: c.glassSource; icon: "shuffle"
            active: c.theme && c.theme.shuffle
            onClicked: c.theme.requestShuffle()
        }
        IdleButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: c.transport
            unit: c.unit; glass: c.glass; glassSource: c.glassSource; icon: "prev"
            onClicked: c.theme.requestPrevious()
        }
        IdleButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: c.transport
            unit: c.unit; glass: c.glass; glassSource: c.glassSource; primary: true
            icon: c.theme && c.theme.playing ? "pause" : "play"
            onClicked: c.theme.requestTogglePlay()
        }
        IdleButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: c.transport
            unit: c.unit; glass: c.glass; glassSource: c.glassSource; icon: "next"
            onClicked: c.theme.requestNext()
        }
        IdleButton {
            anchors.verticalCenter: parent.verticalCenter
            unit: c.unit; glass: c.glass; glassSource: c.glassSource; icon: "repeat"
            active: c.theme && c.theme.repeatMode !== 0
            badge: c.theme && c.theme.repeatMode === 2 ? "1" : ""
            onClicked: c.theme.requestRepeat()
        }
        Item { width: 1.6 * c.unit; height: 1 }
        IdleButton {
            anchors.verticalCenter: parent.verticalCenter
            unit: c.unit; glass: c.glass; glassSource: c.glassSource
            icon: !c.theme || c.theme.muted || c.theme.volume === 0 ? "mute" : (c.theme.volume < 0.5 ? "volumeLow" : "volume")
            onClicked: c.theme.requestMute()
        }
        VolumeSlider {
            anchors.verticalCenter: parent.verticalCenter
            visible: !c.compact
            width: 18 * c.unit
            unit: c.unit; glass: c.glass; liquid: c.glassSource !== null
            theme: c.theme
        }
    }
}
