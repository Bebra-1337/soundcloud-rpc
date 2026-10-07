import QtQuick
import QtQuick.Layouts
import ScBackend

// Library: likes, playlists & albums, listening history, following.
Item {
    id: root

    property string section: "likes"
    readonly property string me: Api.ready ? "/users/" + Api.me.id : ""
    readonly property var sections: [
        { key: "likes", label: qsTr("Likes"), grid: false, title: qsTr("Liked tracks"), path: () => root.me ? root.me + "/track_likes" : "" },
        { key: "playlists", label: qsTr("Playlists & albums"), grid: true, title: qsTr("Playlists"), path: () => Api.ready ? "/me/library/all" : "" },
        { key: "history", label: qsTr("History"), grid: false, title: qsTr("History"), path: () => Api.ready ? "/me/play-history/tracks" : "" },
        { key: "following", label: qsTr("Following"), grid: true, title: qsTr("Following"), path: () => root.me ? root.me + "/followings" : "" }
    ]

    // Lists made elsewhere (likes from the phone, history from the site) change behind our back: a section
    // shown again after a while reloads, and the refresh button reloads it right away.
    readonly property int staleAfterMs: 2 * 60 * 1000

    function refresh(list, force) {
        if (!list || !list.listModel || !(force || list.listModel.isStale(staleAfterMs)))
            return
        list.listModel.refresh()
        if (list.sectionKey === "likes")
            Api.refreshLikedIds()
    }
    function currentList() {
        const loader = sectionRepeater.itemAt(root.sections.findIndex(s => s.key === root.section))
        return loader ? loader.item : null
    }
    onVisibleChanged: if (visible) refresh(currentList(), false)

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: qsTr("Library")
        IconButton { icon: "refresh"; tip: "Refresh"; onClicked: root.refresh(root.currentList(), true) }
    }

    ChipBar {
        id: chips
        anchors.top: header.bottom
        x: Style.gutter
        chips: root.sections
        current: root.section
        onPicked: (key) => root.section = key
    }

    StackLayout {
        anchors.top: chips.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        width: parent.width
        currentIndex: root.sections.findIndex(s => s.key === root.section)

        Repeater {
            id: sectionRepeater
            model: root.sections
            Loader {
                id: sectionLoader
                required property var modelData
                // created when first shown, then kept
                active: false
                Component.onCompleted: if (StackLayout.isCurrentItem) active = true
                StackLayout.onIsCurrentItemChanged: {
                    if (!StackLayout.isCurrentItem)
                        return
                    if (active)
                        root.refresh(item, false)
                    else
                        active = true
                }
                sourceComponent: sectionLoader.modelData.grid ? gridComp : listComp

                Component {
                    id: listComp
                    ItemList {
                        id: list
                        readonly property string sectionKey: sectionLoader.modelData.key
                        contextTitle: sectionLoader.modelData.title
                        listModel: PagedListModel { path: sectionLoader.modelData.path(); pageSize: 50; cached: true }
                        // likes and unlikes made here show up at once
                        Connections {
                            target: Api
                            enabled: list.sectionKey === "likes"
                            function onLikeChanged(track, liked) {
                                if (!liked)
                                    list.listModel.removeById(track.id)
                                else if (track.title)
                                    list.listModel.prepend(track)
                                else
                                    list.listModel.refresh()
                            }
                        }
                    }
                }
                Component {
                    id: gridComp
                    ItemGrid {
                        readonly property string sectionKey: sectionLoader.modelData.key
                        contextTitle: sectionLoader.modelData.title
                        listModel: PagedListModel { path: sectionLoader.modelData.path(); pageSize: 50; cached: true }
                    }
                }
            }
        }
    }
}
