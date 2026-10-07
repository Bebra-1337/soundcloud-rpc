import QtQuick
import QtQuick.Controls.Basic

// Page title row: back button when the page was pushed on its section's stack, title, actions on the right.
Item {
    id: header

    property Item page
    property string title
    property string subtitle
    default property alias actions: actionRow.data

    readonly property var stack: page && page.StackView ? page.StackView.view : null
    readonly property bool canGoBack: stack !== null && stack.depth > 1

    height: 64

    Row {
        anchors.left: parent.left
        anchors.leftMargin: header.canGoBack ? Style.gutter - 10 : Style.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: header.canGoBack
            icon: "back"
            tip: "Back"
            onClicked: header.stack.pop()
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: header.title
                color: Style.ink
                font.pixelSize: 22
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: Math.min(implicitWidth, header.width - actionRow.width - 120)
            }
            Text {
                visible: header.subtitle !== ""
                text: header.subtitle
                color: Style.inkDim
                font.pixelSize: 12
            }
        }
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: Style.gutter - 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
