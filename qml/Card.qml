import QtQuick

// Square artwork card (shelves and grids). Users get a round avatar.
Item {
    id: card

    property var item: ({})
    signal activated()
    signal playRequested()
    signal menuRequested()

    readonly property bool isUser: item.kind === "user"

    width: 150
    height: width + 52

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => mouse.button === Qt.RightButton ? card.menuRequested() : card.activated()
    }
    HoverHandler { id: hover }

    ArtImage {
        id: art
        width: card.width
        height: card.width
        radius: 8
        round: card.isUser
        source: card.item.artworkLarge || card.item.artwork || ""
        fallback: card.item.artworkFallback || ""
        scale: hover.hovered ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.right: art.right
        anchors.bottom: art.bottom
        anchors.margins: 10
        width: 40
        height: 40
        radius: 20
        color: playHover.hovered ? "#ffffff" : Style.ink
        visible: !card.isUser
        opacity: hover.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: "play"; size: 18; color: Style.inkOnLight }
        HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: card.playRequested() }
    }

    Column {
        anchors.top: art.bottom
        anchors.topMargin: 8
        width: card.width
        spacing: 2
        Text {
            width: parent.width
            text: card.item.title || ""
            color: Style.ink
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            horizontalAlignment: card.isUser ? Text.AlignHCenter : Text.AlignLeft
        }
        Text {
            width: parent.width
            text: Style.subtitle(card.item)
            color: Style.inkDim
            font.pixelSize: 12
            elide: Text.ElideRight
            horizontalAlignment: card.isUser ? Text.AlignHCenter : Text.AlignLeft
        }
    }
}
