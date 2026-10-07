import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// Narrow navigation rail on the left: sections, and settings and the signed-in user at the bottom.
Rectangle {
    id: rail

    property int current: 0
    signal navigate(int index)
    signal openMe()

    readonly property int settingsIndex: sections.length  // the gear above the avatar
    readonly property var sections: [
        { icon: "home", label: "Home" },
        { icon: "feed", label: "Feed" },
        { icon: "library", label: "Library" },
        { icon: "search", label: "Search" }
    ]

    width: Style.railWidth
    color: Style.panel

    Image {
        id: logo
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        width: 40
        height: 22
        source: "qrc:/logo.png"
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: 22
        spacing: 6

        Repeater {
            model: rail.sections
            RailButton {
                required property var modelData
                required property int index
                icon: modelData.icon
                label: modelData.label
                active: rail.current === index
                onTapped: rail.navigate(index)
            }
        }
    }

    RailButton {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: avatar.top
        anchors.bottomMargin: 14
        icon: "settings"
        label: "Settings"
        active: rail.current === rail.settingsIndex
        onTapped: rail.navigate(rail.settingsIndex)
    }

    component RailButton: Item {
        id: entry
        property string icon
        property string label
        property bool active
        signal tapped()
        width: 48
        height: 44

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: entry.active ? Style.raised : (hh.hovered ? Style.surface : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Rectangle {
            x: -10
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: entry.active ? 20 : 0
            radius: 2
            color: Style.accent
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        Icon {
            anchors.centerIn: parent
            name: entry.icon
            size: 22
            color: entry.active || hh.hovered ? Style.ink : Style.inkFaint
        }
        HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: entry.tapped() }
        ToolTip.visible: hh.hovered
        ToolTip.text: entry.label
        ToolTip.delay: 500
    }

    ArtImage {
        id: avatar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: 34
        height: 34
        round: true
        visible: Api.ready
        source: Api.me.artwork || ""
        fallback: Api.me.artworkLarge || ""
        HoverHandler { id: avatarHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: rail.openMe() }
        ToolTip.visible: avatarHover.hovered
        ToolTip.text: Api.me.username || ""
        ToolTip.delay: 500
    }
}
