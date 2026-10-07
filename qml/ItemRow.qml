import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// One list row for any item kind: track, playlist/album, user.
Item {
    id: row

    property var item: ({})
    property int number: -1  // track number column when >= 0
    property bool current: isTrack && Player.hasTrack && Player.current.id === item.id

    signal activated()
    signal menuRequested()

    readonly property bool isTrack: item.kind === "track"
    readonly property bool playable: item.playable !== false
    readonly property bool liked: isTrack && Api.likesRevision >= 0 && Api.isLiked(item.id)

    height: 54

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: hover.hovered || row.current ? Style.surface : "transparent"
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => mouse.button === Qt.RightButton ? row.menuRequested() : row.activated()
    }
    HoverHandler { id: hover }

    Item {
        id: numberCol
        visible: row.number >= 0
        width: visible ? 30 : 0
        height: parent.height
        x: 6
        Text {
            anchors.centerIn: parent
            visible: !row.current
            text: row.number + 1
            color: Style.inkFaint
            font.pixelSize: 12
            font.features: { "tnum": 1 }
        }
        PlayingBars {
            anchors.centerIn: parent
            visible: row.current
            running: row.current && Player.playing
        }
    }

    ArtImage {
        id: art
        anchors.left: numberCol.right
        anchors.leftMargin: row.number >= 0 ? 6 : 8
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        round: row.item.kind === "user"
        source: row.item.artwork || ""
        fallback: row.item.artworkFallback || ""
        opacity: row.playable ? 1 : 0.45

        PlayingBars {
            anchors.centerIn: parent
            visible: row.current && row.number < 0
            running: Player.playing
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 12
        anchors.right: meta.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: row.item.title || ""
            color: row.playable ? Style.ink : Style.inkFaint
            font.pixelSize: 14
            font.weight: row.current ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: Style.subtitle(row.item)
            color: Style.inkDim
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Row {
        id: meta
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.item.snippet === true
            width: previewLabel.implicitWidth + 12
            height: 18
            radius: 4
            color: "transparent"
            border.color: Style.outline
            Text { id: previewLabel; anchors.centerIn: parent; text: "PREVIEW"; color: Style.inkDim; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
            HoverHandler { id: previewHover }
            ToolTip.visible: previewHover.hovered
            ToolTip.text: row.item.fullOnlyOnSite
                          ? "30-second preview here: the full track is DRM-protected and plays in full only on soundcloud.com"
                          : "30-second preview: SoundCloud gives this account only a snippet (Go+)"
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.isTrack && !row.playable
            name: "lock"
            size: 16
            color: Style.inkFaint
            HoverHandler { id: lockHover }
            ToolTip.visible: lockHover.hovered
            ToolTip.text: "Only playable on soundcloud.com (DRM)"
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.isTrack && (hover.hovered || row.liked)
            size: 30
            iconSize: 17
            icon: "heart"
            filled: row.liked
            active: row.liked
            tip: row.liked ? "Unlike" : "Like"
            onClicked: Api.setLiked(row.item.id, !row.liked)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: row.isTrack ? Style.fmtTime(row.item.durationMs)
                : (row.item.trackCount ? row.item.trackCount + " tracks" : "")
            color: Style.inkFaint
            font.pixelSize: 12
            font.features: { "tnum": 1 }
        }
    }
}
