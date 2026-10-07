import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// The play queue; click a track to jump to it.
Item {
    id: root

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: qsTr("Queue")
        subtitle: Player.contextTitle ? qsTr("Playing from %1").arg(Player.contextTitle) : ""
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        leftMargin: Style.gutter - 8
        rightMargin: Style.gutter - 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Player.queue
        ScrollBar.vertical: ScrollBar { }
        delegate: ItemRow {
            required property var modelData
            required property int index
            width: ListView.view.width - list.leftMargin - list.rightMargin
            item: modelData
            number: index
            current: index === Player.queueIndex
            onActivated: Player.jumpTo(index)
            onMenuRequested: App.showMenu(modelData)
        }
        Component.onCompleted: if (Player.queueIndex >= 0) positionViewAtIndex(Player.queueIndex, ListView.Center)

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: qsTr("The queue is empty")
            color: Style.inkFaint
            font.pixelSize: 14
        }
    }
}
