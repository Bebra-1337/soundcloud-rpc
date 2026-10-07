import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// Search everything, or paste a soundcloud.com link to open it.
Item {
    id: root

    property string kind: "all"
    property string query: ""
    readonly property var kinds: [
        { key: "all", label: qsTr("Everything"), path: "/search", grid: false },
        { key: "tracks", label: qsTr("Tracks"), path: "/search/tracks", grid: false },
        { key: "people", label: qsTr("People"), path: "/search/users", grid: true },
        { key: "playlists", label: qsTr("Playlists"), path: "/search/playlists_without_albums", grid: true },
        { key: "albums", label: qsTr("Albums"), path: "/search/albums", grid: true }
    ]
    readonly property var currentKind: kinds.find(k => k.key === kind)
    readonly property bool isLink: /^(https?:\/\/)?(on\.|m\.|www\.)?soundcloud\.com\//.test(field.text.trim())

    function focusField() {
        field.forceActiveFocus()
        field.selectAll()
    }

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: qsTr("Search")
    }

    TextField {
        id: field
        anchors.top: header.bottom
        x: Style.gutter
        width: Math.min(parent.width - 2 * Style.gutter, 560)
        height: 40
        leftPadding: 40
        placeholderText: qsTr("Artists, tracks, playlists… or a soundcloud.com link")
        color: Style.ink
        placeholderTextColor: Style.inkFaint
        selectionColor: Style.hover
        font.pixelSize: 14
        background: Rectangle {
            radius: 20
            color: Style.raised
            border.color: field.activeFocus ? Style.inkFaint : "transparent"
        }
        Icon {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 18
            color: Style.inkFaint
        }
        onTextEdited: if (!root.isLink) debounce.restart()
        onAccepted: {
            if (root.isLink) {
                const url = text.trim()
                App.openSoundCloudUrl(url.startsWith("http") ? url : "https://" + url)
            } else {
                debounce.stop()
                root.query = text.trim()
            }
        }
        Keys.onEscapePressed: focus = false
    }
    Timer {
        id: debounce
        interval: 350
        onTriggered: root.query = field.text.trim()
    }

    ChipBar {
        id: chips
        anchors.top: field.bottom
        anchors.topMargin: 12
        x: Style.gutter
        visible: root.query !== ""
        chips: root.kinds
        current: root.kind
        onPicked: (key) => root.kind = key
    }

    Loader {
        anchors.top: chips.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        width: parent.width
        active: root.query !== ""
        sourceComponent: root.currentKind.grid ? gridComp : listComp
    }
    Component {
        id: listComp
        ItemList {
            contextTitle: qsTr("Search: %1").arg(root.query)
            emptyText: "No results"
            listModel: PagedListModel { path: root.currentKind.path; query: ({ q: root.query }) }
        }
    }
    Component {
        id: gridComp
        ItemGrid {
            emptyText: "No results"
            listModel: PagedListModel { path: root.currentKind.path; query: ({ q: root.query }) }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.query === ""
        text: root.isLink ? qsTr("Press Enter to open the link") : qsTr("Find artists, tracks and playlists")
        color: Style.inkFaint
        font.pixelSize: 14
    }
}
