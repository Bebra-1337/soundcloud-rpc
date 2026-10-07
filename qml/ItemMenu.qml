import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// Right-click menu for any item.
Menu {
    id: menu

    property var item: ({})
    readonly property bool isTrack: item.kind === "track"

    function openFor(it) {
        item = it
        popup()
    }

    width: 220
    background: Rectangle {
        implicitWidth: 220
        color: Style.raised
        radius: 10
        border.color: Style.outline
    }

    MenuItem {
        text: menu.isTrack ? "Play" : "Open"
        onTriggered: menu.isTrack ? Player.playTrack(menu.item) : App.openItem(menu.item)
    }
    MenuItem {
        text: "Play next"
        enabled: menu.isTrack && menu.item.playable !== false
        onTriggered: Player.playNext(menu.item)
    }
    MenuItem {
        text: "Add to queue"
        enabled: menu.isTrack && menu.item.playable !== false
        onTriggered: Player.enqueue(menu.item)
    }
    MenuItem {
        text: Api.likesRevision >= 0 && Api.isLiked(menu.item.id) ? "Unlike" : "Like"
        enabled: menu.isTrack
        onTriggered: Api.setLiked(menu.item.id, !Api.isLiked(menu.item.id))
    }
    MenuItem {
        text: "Go to artist"
        enabled: menu.item.userId > 0
        onTriggered: App.openItem({ kind: "user", id: menu.item.userId, title: menu.item.artist })
    }
    MenuSeparator { }
    MenuItem {
        text: "Copy link"
        enabled: !!menu.item.permalinkUrl
        onTriggered: App.copyLink(menu.item.permalinkUrl)
    }
    MenuItem {
        text: "Open on soundcloud.com"
        enabled: !!menu.item.permalinkUrl
        onTriggered: App.openExternal(menu.item.permalinkUrl)
    }
}
