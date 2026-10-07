import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// Right-click menu for any item. The entries draw their own rounded highlight inset from the menu's edges: the
// Basic style's square one reached past the menu's rounded corners on the first and last entry.
Menu {
    id: menu

    property var item: ({})
    readonly property bool isTrack: item.kind === "track"

    function openFor(it) {
        item = it
        popup()
    }

    width: 220
    topPadding: 5
    bottomPadding: 5
    background: Rectangle {
        implicitWidth: 220
        color: Style.raised
        radius: 10
        border.color: Style.outline
    }

    Entry {
        text: menu.isTrack ? qsTr("Play") : qsTr("Open")
        onTriggered: menu.isTrack ? Player.playTrack(menu.item) : App.openItem(menu.item)
    }
    Entry {
        text: qsTr("Play next")
        enabled: menu.isTrack && menu.item.playable !== false
        onTriggered: Player.playNext(menu.item)
    }
    Entry {
        text: qsTr("Add to queue")
        enabled: menu.isTrack && menu.item.playable !== false
        onTriggered: Player.enqueue(menu.item)
    }
    Entry {
        text: Api.likesRevision >= 0 && Api.isLiked(menu.item.id) ? qsTr("Unlike") : qsTr("Like")
        enabled: menu.isTrack
        onTriggered: Api.setLiked(menu.item.id, !Api.isLiked(menu.item.id))
    }
    Entry {
        text: qsTr("Go to artist")
        enabled: menu.item.userId > 0
        onTriggered: App.openItem({ kind: "user", id: menu.item.userId, title: menu.item.artist })
    }
    MenuSeparator {
        topPadding: 4
        bottomPadding: 4
        contentItem: Rectangle {
            implicitHeight: 1
            color: Style.outline
        }
    }
    Entry {
        text: qsTr("Copy link")
        enabled: !!menu.item.permalinkUrl
        onTriggered: App.copyLink(menu.item.permalinkUrl)
    }
    Entry {
        text: qsTr("Open on soundcloud.com")
        enabled: !!menu.item.permalinkUrl
        onTriggered: App.openExternal(menu.item.permalinkUrl)
    }

    component Entry: MenuItem {
        id: entry
        implicitHeight: 34
        leftPadding: 14
        rightPadding: 14
        contentItem: Text {
            text: entry.text
            color: entry.enabled ? Style.ink : Style.inkFaint
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            x: 5
            width: entry.width - 10
            height: entry.height
            radius: 6
            color: entry.down ? Style.outline : (entry.highlighted ? Style.hover : "transparent")
        }
    }
}
