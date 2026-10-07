import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// A playlist, album or SoundCloud-made playlist: info on the left, tracks on the right.
Item {
    id: root

    property var item: ({})
    property var info: item
    property bool loading: true
    property string error: ""

    readonly property string kindLabel: item.kind === "system-playlist" || item.kind === "station" ? "Made for you"
                                        : info.isAlbum ? "Album" : "Playlist"

    Component.onCompleted: {
        Api.loadPlaylist(item.urn || item.id, (result, err) => {
            root.loading = false
            if (!result) {
                root.error = err || "error"
                return
            }
            root.info = Object.assign({}, root.item, result.info)
            tracks.setItems(result.items)
        })
    }

    PagedListModel { id: tracks }

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: root.kindLabel
    }

    Column {
        id: side
        anchors.top: header.bottom
        x: Style.gutter
        width: 200
        spacing: 6

        ArtImage {
            width: 200
            height: 200
            radius: 10
            source: root.info.artworkLarge || root.info.artwork || ""
            fallback: root.info.artworkFallback || ""
        }
        Item { width: 1; height: 4 }
        Text {
            width: parent.width
            text: root.info.title || ""
            color: Style.ink
            font.pixelSize: 16
            font.weight: Font.Bold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.info.artist || ""
            color: ownerHover.hovered && root.info.userId > 0 ? Style.ink : Style.inkDim
            font.pixelSize: 13
            elide: Text.ElideRight
            HoverHandler { id: ownerHover; cursorShape: root.info.userId > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler {
                enabled: root.info.userId > 0
                onTapped: App.openItem({ kind: "user", id: root.info.userId, title: root.info.artist })
            }
        }
        Text {
            text: (tracks.count || root.info.trackCount || 0) + " tracks"
                  + (root.info.durationMs > 0 ? " · " + Style.fmtTime(root.info.durationMs) : "")
            color: Style.inkFaint
            font.pixelSize: 12
        }
        Row {
            spacing: 6
            topPadding: 6
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: playHover.hovered ? "#ffffff" : Style.ink
                opacity: tracks.count > 0 ? 1 : 0.4
                Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: "play"; size: 20; color: Style.inkOnLight }
                HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: if (tracks.count > 0) {
                        Player.shuffle = false
                        Player.playList(tracks.items(), 0, root.info.title)
                    }
                }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "shuffle"
                tip: "Shuffle play"
                onClicked: if (tracks.count > 0) {
                    Player.shuffle = true
                    Player.playList(tracks.items(), Math.floor(Math.random() * tracks.count), root.info.title)
                }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.info.permalinkUrl
                icon: "external"
                tip: "Open on soundcloud.com"
                onClicked: App.openExternal(root.info.permalinkUrl)
            }
        }
    }

    ItemList {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: side.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        leftMargin: 0
        numbered: true
        contextTitle: root.info.title || ""
        listModel: tracks
        emptyText: root.error ? "Couldn't load (" + root.error + ")" : "This playlist is empty"
    }
    Spinner {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: side.width / 2
        visible: root.loading
        color: Style.inkDim
    }
}
