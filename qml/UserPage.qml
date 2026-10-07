import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import ScBackend

// An artist / user: avatar and stats on the left, their tracks, playlists and likes on the right.
Item {
    id: root

    property var item: ({})
    property var info: item
    property string section: "tracks"

    readonly property string base: "/users/" + item.id
    readonly property var sections: [
        { key: "tracks", label: qsTr("Tracks"), grid: false, path: base + "/tracks" },
        { key: "popular", label: qsTr("Popular"), grid: false, path: base + "/toptracks" },
        { key: "playlists", label: qsTr("Playlists"), grid: true, path: base + "/playlists_without_albums" },
        { key: "albums", label: qsTr("Albums"), grid: true, path: base + "/albums" },
        { key: "likes", label: qsTr("Likes"), grid: false, path: base + "/likes" }
    ]

    Component.onCompleted: Api.loadUser(item.id, (result) => { if (result) root.info = result })

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: root.info.title || ""
        //: %1 is the count, shortened like 1.2K; the plural form follows the exact number
        subtitle: root.info.followers ? qsTr("%1 followers", "", root.info.followers).arg(Style.fmtCount(root.info.followers)) : ""
        IconButton {
            visible: !!root.info.permalinkUrl
            icon: "external"
            tip: qsTr("Open on soundcloud.com")
            onClicked: App.openExternal(root.info.permalinkUrl)
        }
    }

    Column {
        id: side
        anchors.top: header.bottom
        x: Style.gutter
        width: 170
        spacing: 8
        ArtImage {
            width: 150
            height: 150
            round: true
            source: root.info.artworkLarge || root.info.artwork || ""
        }
        Text {
            width: parent.width
            visible: !!root.info.artist
            text: root.info.artist || ""
            color: Style.inkDim
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: root.info.trackCount > 0
            text: qsTr("%n track(s)", "", root.info.trackCount)
            color: Style.inkFaint
            font.pixelSize: 12
        }
    }

    ChipBar {
        id: chips
        anchors.top: header.bottom
        anchors.left: side.right
        anchors.leftMargin: 16
        chips: root.sections
        current: root.section
        onPicked: (key) => root.section = key
    }

    StackLayout {
        anchors.top: chips.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        anchors.left: side.right
        anchors.right: parent.right
        currentIndex: root.sections.findIndex(s => s.key === root.section)
        Repeater {
            model: root.sections
            Loader {
                id: sectionLoader
                required property var modelData
                // created when first shown, then kept
                active: false
                Component.onCompleted: if (StackLayout.isCurrentItem) active = true
                StackLayout.onIsCurrentItemChanged: if (StackLayout.isCurrentItem) active = true
                sourceComponent: sectionLoader.modelData.grid ? gridComp : listComp
                Component {
                    id: listComp
                    ItemList {
                        leftMargin: 0
                        contextTitle: (root.info.title || "") + " · " + sectionLoader.modelData.label
                        listModel: PagedListModel { path: sectionLoader.modelData.path; pageSize: 50 }
                    }
                }
                Component {
                    id: gridComp
                    ItemGrid {
                        leftMargin: 4
                        listModel: PagedListModel { path: sectionLoader.modelData.path; pageSize: 50 }
                    }
                }
            }
        }
    }
}
