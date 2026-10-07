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

        ArtImage {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64
            height: 64
            radius: 16
            source: "qrc:/soundcloud.png"
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Api.signedIn ? "Connecting to SoundCloud…" : "Sign in to SoundCloud"
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
                  ? "Finish signing in in the SoundCloud window. It closes by itself once you're in."
                  : "Use your own SoundCloud account, the same as on soundcloud.com. The sign-in page opens in a separate window, once."
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
                text: Auth.signingIn ? "Show sign-in window" : "Sign in"
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
