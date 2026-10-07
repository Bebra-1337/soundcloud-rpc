import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// Grid of cards over a PagedListModel (playlists, albums, people).
GridView {
    id: grid

    property PagedListModel listModel
    property string contextTitle
    property string emptyText: qsTr("Nothing here yet")

    readonly property int columns: Math.max(1, Math.floor((width - leftMargin - rightMargin) / 172))

    model: listModel
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    leftMargin: Style.gutter
    rightMargin: Style.gutter - 14
    cellWidth: Math.floor((width - leftMargin - rightMargin) / columns)
    cellHeight: cellWidth - 14 + 58
    ScrollBar.vertical: ScrollBar { }

    delegate: Item {
        required property var model
        required property int index
        width: grid.cellWidth
        height: grid.cellHeight
        Card {
            width: parent.width - 14
            item: model.item
            onActivated: grid.activate(index, model.item)
            onPlayRequested: model.item.kind === "track" ? grid.activate(index, model.item)
                                                        : App.playCollection(model.item)
            onMenuRequested: App.showMenu(model.item)
        }
    }

    function activate(i, it) {
        if (it.kind === "track")
            Player.playList(listModel.items(), i, contextTitle)
        else
            App.openItem(it)
    }

    function maybeMore() {
        if (listModel && listModel.hasMore && !listModel.loading && contentHeight - contentY - height < 800)
            listModel.loadMore()
    }
    onContentYChanged: maybeMore()
    onCountChanged: Qt.callLater(maybeMore)
    onHeightChanged: maybeMore()

    footer: Item {
        width: grid.width
        height: grid.listModel && grid.listModel.loading ? 64 : 20
        Spinner {
            anchors.centerIn: parent
            visible: grid.listModel !== null && grid.listModel.loading
            color: Style.inkDim
        }
    }

    Text {
        anchors.centerIn: parent
        visible: grid.listModel !== null && grid.listModel.loaded && !grid.listModel.loading && grid.count === 0
        text: grid.listModel && grid.listModel.error ? qsTr("Couldn't load (%1)").arg(grid.listModel.error) : grid.emptyText
        color: Style.inkFaint
        font.pixelSize: 14
    }
}
