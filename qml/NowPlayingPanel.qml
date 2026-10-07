import QtQuick
import QtQuick.Controls.Basic
import ScBackend
import SoundCloudRpc.Idle

// Right column: cover, title, waveform, transport, like/queue/idle/volume.
Rectangle {
    id: panel

    signal openQueue()
    signal openArtist()

    readonly property var track: Player.current
    // the cover as actually loaded, for the backdrop, the idle screen, Discord and MPRIS
    readonly property url coverUrl: cover.resolved
    Binding { target: Player; property: "displayedArtwork"; value: "" + panel.coverUrl }
    readonly property bool liked: Player.hasTrack && Api.likesRevision >= 0 && Api.isLiked(track.id)

    width: Style.panelWidth
    color: Style.panel
    clip: true

    BlurBackdrop {
        anchors.fill: parent
        visible: Player.hasTrack
        source: panel.coverUrl
        brightness: -0.55
        saturation: -0.4
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00111111" }
            GradientStop { position: 1.0; color: "#cc111111" }
        }
    }

    // nothing loaded yet
    Column {
        anchors.centerIn: parent
        visible: !Player.hasTrack
        spacing: 12
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "note"; size: 40; color: Style.inkFaint }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pick something to play"
            color: Style.inkDim
            font.pixelSize: 14
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        visible: Player.hasTrack

        readonly property real coverSize: Math.max(80, Math.min(width, height - 270))

        ArtImage {
            id: cover
            anchors.horizontalCenter: parent.horizontalCenter
            width: content.coverSize
            height: content.coverSize
            radius: 10
            source: panel.track.artworkLarge || ""
            fallback: panel.track.artworkFallback || ""
            scale: coverHover.hovered ? 1.015 : 1
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            HoverHandler { id: coverHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: App.showIdle() }
            ToolTip.visible: coverHover.hovered
            ToolTip.text: "Idle screen"
            ToolTip.delay: 800

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 8
                visible: panel.track.snippet === true
                width: snipLabel.implicitWidth + 14
                height: 20
                radius: 5
                color: "#cc111111"
                Text { id: snipLabel; anchors.centerIn: parent; text: "PREVIEW"; color: Style.ink; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
            }
        }

        Column {
            id: titles
            anchors.top: cover.bottom
            anchors.topMargin: 14
            width: parent.width
            spacing: 3
            Text {
                width: parent.width
                text: panel.track.title || ""
                color: Style.ink
                font.pixelSize: 17
                font.weight: Font.Bold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: panel.track.artist || ""
                color: artistHover.hovered ? Style.ink : Style.inkDim
                font.pixelSize: 13
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                HoverHandler { id: artistHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: panel.openArtist() }
            }
        }

        Waveform {
            id: wave
            anchors.top: titles.bottom
            anchors.topMargin: 12
            width: parent.width
            height: 34
        }
        Item {
            id: times
            anchors.top: wave.bottom
            anchors.topMargin: 4
            width: parent.width
            height: 14
            Text {
                text: Style.fmtTime(wave.dragProgress >= 0 ? wave.dragProgress * Player.duration : Player.position)
                color: Style.inkDim
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.right: parent.right
                text: Style.fmtTime(Player.duration)
                color: Style.inkFaint
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
        }

        Row {
            id: transport
            anchors.top: times.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "shuffle"
                active: Player.shuffle
                color: Style.inkFaint
                tip: Player.shuffle ? "Shuffle on" : "Shuffle off"
                onClicked: Player.shuffle = !Player.shuffle
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "prev"
                color: Style.ink
                tip: "Previous"
                onClicked: Player.previous()
            }
            Rectangle {
                width: 50
                height: 50
                radius: 25
                color: playHover.hovered ? "#ffffff" : Style.ink
                scale: playTap.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }
                Icon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: Player.playing ? 0 : 1
                    name: Player.playing ? "pause" : "play"
                    size: 22
                    color: Style.inkOnLight
                }
                Spinner {
                    anchors.fill: parent
                    anchors.margins: -5
                    visible: Player.loading
                    lineWidth: 2
                    color: Style.ink
                }
                HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: playTap; onTapped: Player.togglePlay() }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "next"
                color: Style.ink
                tip: "Next"
                onClicked: Player.next()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "repeat"
                active: Player.repeatMode !== 0
                color: Style.inkFaint
                tip: ["Repeat off", "Repeat all", "Repeat one"][Player.repeatMode]
                onClicked: Player.cycleRepeat()
                Text {
                    visible: Player.repeatMode === 2
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 3
                    text: "1"
                    color: Style.ink
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }
        }

        Row {
            anchors.top: transport.bottom
            anchors.topMargin: 6
            width: parent.width
            spacing: 2

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                iconSize: 18
                icon: "heart"
                filled: panel.liked
                active: panel.liked
                tip: panel.liked ? "Unlike" : "Like"
                onClicked: Api.setLiked(panel.track.id, !panel.liked)
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                iconSize: 18
                icon: "queue"
                tip: "Queue"
                onClicked: panel.openQueue()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                iconSize: 18
                icon: "screen"
                tip: "Idle screen"
                onClicked: App.showIdle()
            }
            Item { width: parent.width - 32 * 4 - 2 * 4 - volume.width; height: 1 }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                iconSize: 18
                icon: Player.muted || Player.volume === 0 ? "mute" : (Player.volume < 0.5 ? "volumeLow" : "volume")
                tip: Player.muted ? "Unmute" : "Mute"
                onClicked: Player.muted = !Player.muted
            }
            Slider {
                id: volume
                anchors.verticalCenter: parent.verticalCenter
                width: 96
                from: 0
                to: 1
                value: Player.volume
                onMoved: { Player.volume = value; Player.muted = false }
                background: Rectangle {
                    x: volume.leftPadding
                    y: volume.topPadding + volume.availableHeight / 2 - height / 2
                    width: volume.availableWidth
                    height: 3
                    radius: 2
                    color: Style.outline
                    Rectangle {
                        width: volume.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: Player.muted ? Style.inkFaint : Style.ink
                    }
                }
                handle: Rectangle {
                    x: volume.leftPadding + volume.visualPosition * (volume.availableWidth - width)
                    y: volume.topPadding + volume.availableHeight / 2 - height / 2
                    width: 12
                    height: 12
                    radius: 6
                    color: Style.ink
                    visible: volume.hovered || volume.pressed
                }
            }
        }
    }
}
