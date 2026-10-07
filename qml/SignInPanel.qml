import QtQuick
import QtQuick.Controls.Basic
import ScBackend

// Shown over the content until the API is signed in and knows who the user is.
Rectangle {
    id: panel

    color: Style.bg

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        spacing: 14

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 128
            height: 58
            source: Style.logo
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Api.signedIn ? qsTr("Connecting to SoundCloud…") : qsTr("Sign in to SoundCloud")
            color: Style.ink
            font.pixelSize: 22
            font.weight: Font.Bold
        }
        Text {
            width: parent.width
            visible: !Api.signedIn
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Auth.signingIn
                  ? qsTr("Finish signing in in the SoundCloud window. It closes by itself once you're in.")
                  : qsTr("Use your own SoundCloud account, the same as on soundcloud.com. The sign-in page opens in a separate window, once.")
            color: Style.inkDim
            font.pixelSize: 13
            lineHeight: 1.2
        }
        Item { width: 1; height: 4 }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Api.signedIn
            width: signLabel.implicitWidth + 44
            height: 40
            radius: 20
            color: signHover.hovered ? Style.accentHover : Style.accent
            Text {
                id: signLabel
                anchors.centerIn: parent
                text: Auth.signingIn ? qsTr("Show sign-in window") : qsTr("Sign in")
                color: Style.onAccent
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            HoverHandler { id: signHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Auth.signIn() }
        }
        Spinner {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Api.signedIn
            color: Style.inkDim
        }
    }
}
