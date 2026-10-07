import QtQuick
import ScBackend

// Feed: new tracks and reposts from the people you follow.
Item {
    id: root

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: qsTr("Feed")
        subtitle: qsTr("New from the people you follow")
        IconButton { icon: "refresh"; tip: "Refresh"; onClicked: feed.reload() }
    }

    ItemList {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        contextTitle: qsTr("Feed")
        emptyText: qsTr("Follow some artists to fill your feed")
        listModel: PagedListModel {
            id: feed
            path: "/stream"
            cached: true
            pageSize: 40
        }
    }
}
