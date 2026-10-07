import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// Vertical list over a PagedListModel; loads more pages as it scrolls. Clicking a track plays the list from
// there, anything else opens its page.
ListView {
    id: list

    property PagedListModel listModel
    property string contextTitle
    property bool numbered: false
    property string emptyText: "Nothing here yet"

    model: listModel
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    reuseItems: true
    leftMargin: Style.gutter - 8
    rightMargin: Style.gutter - 8
    ScrollBar.vertical: ScrollBar { }

    delegate: ItemRow {
        required property var model
        required property int index
        width: ListView.view.width - list.leftMargin - list.rightMargin
        item: model.item
        number: list.numbered ? index : -1
        onActivated: list.activate(index, model.item)
        onMenuRequested: App.showMenu(model.item)
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
        width: list.width - list.leftMargin - list.rightMargin
        height: list.listModel && list.listModel.loading ? 64 : 20
        Spinner {
            anchors.centerIn: parent
            visible: list.listModel !== null && list.listModel.loading
            color: Style.inkDim
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.listModel !== null && list.listModel.loaded && !list.listModel.loading && list.count === 0
        text: list.listModel && list.listModel.error ? "Couldn't load (" + list.listModel.error + ")" : list.emptyText
        color: Style.inkFaint
        font.pixelSize: 14
    }
}
