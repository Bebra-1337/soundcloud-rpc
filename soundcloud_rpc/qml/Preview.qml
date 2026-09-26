import QtQuick
import QtQuick.Window

// Standalone gallery of idle themes with fake data. Keys: ←/→ theme, Space play/pause,
// T long title, C no cover, A auto-cycle, Esc quit.
Window {
    id: win
    width: 1280
    height: 720
    visible: true
    color: "black"
    title: "Idle themes preview"

    property string shotsDir: ""
    readonly property var themes: ["BlurCover", "Aurora", "Vinyl", "Cassette", "Particles", "Equalizer", "Polaroid",
        "MinimalClock", "Typography", "Neon", "AlbumWall", "Orbit", "GlassCard", "Starfield"]
    property int idx: 0
    property bool playing: true
    property bool longTitle: false
    property bool noCover: false
    property bool autoCycle: false
    property real pos: 61
    readonly property real dur: 227

    Timer {
        interval: 250; repeat: true; running: win.playing
        onTriggered: { win.pos += 0.25; if (win.pos >= win.dur) win.pos = 0 }
    }
    Timer { interval: 12000; repeat: true; running: win.autoCycle; onTriggered: win.idx = (win.idx + 1) % win.themes.length }

    Loader {
        id: ld
        anchors.fill: parent
        source: "themes/" + win.themes[win.idx] + ".qml"
    }
    Binding { target: ld.item; property: "title"; value: win.longTitle ? "Very Long Track Title That Goes On And On (Extended Club Remix) [feat. Someone Else]" : "Midnight City"; when: ld.item }
    Binding { target: ld.item; property: "artist"; value: win.longTitle ? "An Artist With A Really Long Name & Another Collaborator" : "M83"; when: ld.item }
    Binding { target: ld.item; property: "cover"; value: win.noCover ? "" : Qt.resolvedUrl("../soundcloud.png"); when: ld.item }
    Binding { target: ld.item; property: "position"; value: win.pos; when: ld.item }
    Binding { target: ld.item; property: "duration"; value: win.dur; when: ld.item }
    Binding { target: ld.item; property: "playing"; value: win.playing; when: ld.item }
    Binding { target: ld.item; property: "accent"; value: "#aaaaaa"; when: ld.item }
    Binding { target: ld.item; property: "accent2"; value: "#636363"; when: ld.item }

    Item {
        focus: true
        anchors.fill: parent
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Right) win.idx = (win.idx + 1) % win.themes.length
            else if (e.key === Qt.Key_Left) win.idx = (win.idx + win.themes.length - 1) % win.themes.length
            else if (e.key === Qt.Key_Space) win.playing = !win.playing
            else if (e.key === Qt.Key_T) win.longTitle = !win.longTitle
            else if (e.key === Qt.Key_C) win.noCover = !win.noCover
            else if (e.key === Qt.Key_A) win.autoCycle = !win.autoCycle
            else if (e.key === Qt.Key_Escape) Qt.quit()
            hint.opacity = 1; hintFade.restart()
        }
    }
    Text {
        id: hint
        x: 16; y: 12
        text: (win.idx + 1) + "/" + win.themes.length + "  " + win.themes[win.idx]
              + "    ←/→ theme · Space play/pause · T long title · C no cover · A auto · Esc quit"
        color: "white"; style: Text.Outline; styleColor: "black"; font.pixelSize: 15
        z: 100
        SequentialAnimation on opacity { id: hintFade; running: true
            PauseAnimation { duration: 3500 } NumberAnimation { to: 0; duration: 800 } }
    }

    // Screenshot mode: cycle through all themes, save PNGs, quit.
    Timer {
        interval: 2500; repeat: true; running: win.shotsDir !== ""
        onTriggered: {
            ld.grabToImage(function (r) {
                r.saveToFile(win.shotsDir + "/" + (win.idx < 9 ? "0" : "") + (win.idx + 1) + "_" + win.themes[win.idx] + ".png")
                if (win.idx === win.themes.length - 1) Qt.quit(); else win.idx++
            })
        }
    }
}
