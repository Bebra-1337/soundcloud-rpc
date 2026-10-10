import QtQuick

// Poster: the title set as large as it fits, flush left and bottom, the artist in italic serif under it, the cover
// as a plate in the corner and one rule of progress along the foot.
ThemeBase {
    id: root

    background: [
        Rectangle { anchors.fill: parent; color: root.bg }
    ]

    IdleText {
        id: headline
        x: 14 * root.u; y: 10 * root.u
        width: 190 * root.u; height: 46 * root.u
        text: root.title || qsTr("Nothing playing")
        size: 30 * root.u
        fontSizeMode: Text.Fit
        minimumPixelSize: Math.round(8 * root.u)
        weight: 720
        tracking: -0.032
        lineHeight: 0.88
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
        verticalAlignment: Text.AlignBottom
    }
    IdleText {
        x: 14 * root.u
        anchors.top: headline.bottom
        anchors.topMargin: 2 * root.u
        width: 190 * root.u
        text: root.artist
        serif: true
        font.italic: true
        size: 9 * root.u
        color: root.alpha(root.ink, 0.7)
        elide: Text.ElideRight
    }
    Cover {
        x: 214 * root.u; y: 10 * root.u
        width: 58 * root.u; height: width; radius: 0.8 * root.u
        source: root.cover; shadowStrength: 0.5
    }
    // progress, then the controls under it (the same order in every theme)
    Progress {
        id: bar
        x: 14 * root.u; y: 72 * root.u
        width: 258 * root.u
        unit: root.u
        thickness: Math.max(1, Math.round(0.35 * root.u))
        value: root.progress; playing: root.playing; theme: root
        leftText: root.elapsedText; rightText: root.remainingText
    }
    Controls {
        x: 14 * root.u; y: bar.y + bar.height + 1.2 * root.u
        width: 190 * root.u
        unit: root.u
        theme: root
    }
}
