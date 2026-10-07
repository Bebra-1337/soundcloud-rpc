import QtQuick
import ScBackend

// Feed: new tracks and reposts from the people you follow.
Item {
    id: root

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: "Feed"
        subtitle: "New from the people you follow"
        IconButton { icon: "refresh"; tip: "Refresh"; onClicked: feed.reload() }
    }

    ItemList {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        contextTitle: "Feed"
        emptyText: "Follow some artists to fill your feed"
        listModel: PagedListModel {
            id: feed
            path: "/stream"
            pageSize: 40
        }
    }
}
