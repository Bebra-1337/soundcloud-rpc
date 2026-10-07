import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// A titled horizontal row of cards (Home).
Column {
    id: shelf

    property string title
    property var items: []

    spacing: 10

    Item {
        width: shelf.width
        height: 28
        Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.gutter
            anchors.verticalCenter: parent.verticalCenter
            text: shelf.title
            color: Style.ink
            font.pixelSize: 17
            font.weight: Font.Bold
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Style.gutter - 8
            anchors.verticalCenter: parent.verticalCenter
            visible: list.contentWidth > list.width
            IconButton { size: 28; iconSize: 16; icon: "left"; onClicked: list.page(-1) }
            IconButton { size: 28; iconSize: 16; icon: "right"; onClicked: list.page(1) }
        }
    }

    ListView {
        id: list
        width: shelf.width
        height: 150 + 52
        orientation: ListView.Horizontal
        spacing: 16
        leftMargin: Style.gutter
        rightMargin: Style.gutter
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: shelf.items

        function page(dir) {
            const target = Math.max(originX - leftMargin,
                                    Math.min(contentX + dir * (width - 120), originX + contentWidth + rightMargin - width))
            scroll.to = target
            scroll.restart()
        }
        NumberAnimation { id: scroll; target: list; property: "contentX"; duration: 350; easing.type: Easing.OutCubic }

        delegate: Card {
            required property var modelData
            required property int index
            item: modelData
            onActivated: modelData.kind === "track" ? Player.playList(shelf.items, index, shelf.title)
                                                    : App.openItem(modelData)
            onPlayRequested: modelData.kind === "track" ? Player.playList(shelf.items, index, shelf.title)
                                                        : App.playCollection(modelData)
            onMenuRequested: App.showMenu(modelData)
        }
    }
}
