import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// Home: recently played plus SoundCloud's own selections (the shelves of soundcloud.com/discover).
Item {
    id: root

    property var shelves: []
    property bool loading: false
    property string error: ""

    function reload() {
        if (!Api.ready)
            return
        loading = true
        Api.loadHome((result, err) => {
            root.loading = false
            root.shelves = result || []
            root.error = err || ""
        })
    }

    function greeting() {
        const h = new Date().getHours()
        const part = h < 5 ? qsTr("Good night") : h < 12 ? qsTr("Good morning") : h < 18 ? qsTr("Good afternoon") : qsTr("Good evening")
        //: the greeting above Home: %1 is "Good evening" etc., %2 the user's name
        return Api.me.username ? qsTr("%1, %2").arg(part).arg(Api.me.username) : part
    }

    Component.onCompleted: reload()
    Connections {
        target: Api
        function onReadyChanged() { if (Api.ready && root.shelves.length === 0) root.reload() }
    }

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: root.greeting()
        IconButton { icon: "refresh"; tip: "Refresh"; onClicked: root.reload() }
    }

    ListView {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 22
        boundsBehavior: Flickable.StopAtBounds
        model: root.shelves
        bottomMargin: 20
        ScrollBar.vertical: ScrollBar { }
        delegate: Shelf {
            required property var modelData
            width: ListView.view.width
            title: modelData.title
            items: modelData.items
        }
    }

    Spinner {
        anchors.centerIn: parent
        visible: root.loading && root.shelves.length === 0
        color: Style.inkDim
    }
    Text {
        anchors.centerIn: parent
        visible: !root.loading && root.shelves.length === 0 && Api.ready
        text: root.error ? qsTr("Couldn't load Home (%1)").arg(root.error) : qsTr("Nothing to show yet")
        color: Style.inkFaint
        font.pixelSize: 14
    }
}
