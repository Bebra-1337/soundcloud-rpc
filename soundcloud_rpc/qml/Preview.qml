import QtQuick
import QtQuick.Window

// Standalone gallery of idle themes with fake data. Keys: ←/→ theme, Space play/pause,
// T long title, C no cover, A auto-cycle, M fake music signal, Esc quit.
Window {
    id: win
    width: 1280
    height: 720
    visible: true
    color: "black"
    title: "Idle themes preview"

    property string shotsDir: ""
    property url coverUrl: Qt.resolvedUrl("../soundcloud.png")
    property string themeFilter: ""
    readonly property var allThemes: ["BlurCover", "Aurora", "Vinyl", "Cassette", "Particles", "Equalizer", "Polaroid",
        "Stereo", "MinimalClock", "Typography", "Neon", "AlbumWall", "Orbit", "GlassCard", "Starfield"]
    readonly property var themes: themeFilter ? allThemes.filter(function (n) { return themeFilter.split(",").indexOf(n) >= 0 }) : allThemes
    property int idx: 0
    property bool playing: true
    property bool longTitle: false
    property bool noCover: false
    property bool autoCycle: false
    property bool fakeAudio: false
    property bool showFps: false
    property real fakeT: 0
    property real audioB: 0
    property real audioM: 0
    property real audioT: 0
    property real audioL: 0
    property var audioBandsFake: []
    property var audioBandsFakeL: []
    property var audioBandsFakeR: []
    property real pos: 61
    property int frames: 0
    readonly property real dur: 227

    Timer {
        interval: 250; repeat: true; running: win.playing
        onTriggered: { win.pos += 0.25; if (win.pos >= win.dur) win.pos = 0 }
    }
    // stand-in for the page's analyser: raw levels like the real ones (high bass floor, small movement)
    Timer {
        interval: 33; repeat: true; running: win.fakeAudio && win.playing
        onTriggered: {
            win.fakeT += 0.033
            var beatPhase = (win.fakeT * 2) % 1                  // 120 BPM
            var kick = Math.exp(-beatPhase * 7)
            win.audioB = 0.5 + 0.3 * kick + 0.02 * Math.random()
            win.audioM = 0.42 + 0.1 * Math.sin(win.fakeT * 1.3) + 0.06 * kick + 0.02 * Math.random()
            win.audioT = 0.05 + 0.2 * (0.5 + 0.5 * Math.sin(win.fakeT * 0.4)) + 0.03 * Math.random()
            win.audioL = (win.audioB * 4 + win.audioM * 28 + win.audioT * 96) / 128 * 0.5
            var bands = []
            for (var i = 0; i < 32; i++) {
                var f = i / 31
                var tilt = 0.7 - 0.55 * f
                var wob = 0.14 * Math.sin(win.fakeT * (1.1 + i * 0.23) + i * 1.7)
                bands.push(Math.max(0, Math.min(1, tilt + wob + 0.32 * (1 - f) * kick + 0.02 * Math.random())))
            }
            win.audioBandsFake = bands
            var pan = Math.sin(win.fakeT * 0.45)                    // -1 = left only, +1 = right only
            var gl = Math.max(0, Math.min(1, 1 - 1.4 * Math.max(0, pan)))
            var gr = Math.max(0, Math.min(1, 1 + 1.4 * Math.min(0, pan)))
            win.audioBandsFakeL = bands.map(function (v) { return v * gl })
            win.audioBandsFakeR = bands.map(function (v) { return v * gr })
        }
    }
    onPlayingChanged: if (!playing) { audioB = 0; audioM = 0; audioT = 0; audioL = 0; audioBandsFake = []; audioBandsFakeL = []; audioBandsFakeR = [] }
    Timer { interval: 12000; repeat: true; running: win.autoCycle; onTriggered: win.idx = (win.idx + 1) % win.themes.length }

    // --fps: print the rendered frame rate once a second
    Connections { target: win; function onFrameSwapped() { win.frames++ } }
    Timer {
        interval: 1000; repeat: true; running: win.showFps
        onTriggered: { console.log("FPS[" + win.themes[win.idx] + "]: " + win.frames); win.frames = 0 }
    }

    Loader {
        id: ld
        anchors.fill: parent
        source: "themes/" + win.themes[win.idx] + ".qml"
    }
    Binding { target: ld.item; property: "title"; value: win.longTitle ? "Very Long Track Title That Goes On And On (Extended Club Remix) [feat. Someone Else]" : "Midnight City"; when: ld.item }
    Binding { target: ld.item; property: "artist"; value: win.longTitle ? "An Artist With A Really Long Name & Another Collaborator" : "M83"; when: ld.item }
    Binding { target: ld.item; property: "cover"; value: win.noCover ? "" : win.coverUrl; when: ld.item }
    Binding { target: ld.item; property: "position"; value: win.pos; when: ld.item }
    Binding { target: ld.item; property: "duration"; value: win.dur; when: ld.item }
    Binding { target: ld.item; property: "audioBands"; value: win.fakeAudio ? win.audioBandsFake : []; when: ld.item }
    Binding { target: ld.item; property: "audioBandsL"; value: win.fakeAudio ? win.audioBandsFakeL : []; when: ld.item }
    Binding { target: ld.item; property: "audioBandsR"; value: win.fakeAudio ? win.audioBandsFakeR : []; when: ld.item }
    Binding { target: ld.item; property: "audioBass"; value: win.fakeAudio ? win.audioB : 0; when: ld.item }
    Binding { target: ld.item; property: "audioMid"; value: win.fakeAudio ? win.audioM : 0; when: ld.item }
    Binding { target: ld.item; property: "audioTreble"; value: win.fakeAudio ? win.audioT : 0; when: ld.item }
    Binding { target: ld.item; property: "audioLevel"; value: win.fakeAudio ? win.audioL : 0; when: ld.item }
    Binding { target: ld.item; property: "playing"; value: win.playing; when: ld.item }

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
            else if (e.key === Qt.Key_M) win.fakeAudio = !win.fakeAudio
            else if (e.key === Qt.Key_Escape) Qt.quit()
            hint.opacity = 1; hintFade.restart()
        }
    }
    Text {
        id: hint
        x: 16; y: 12
        text: (win.idx + 1) + "/" + win.themes.length + "  " + win.themes[win.idx]
              + "    ←/→ theme · Space play/pause · T long title · C no cover · A auto · M music · Esc quit"
        color: "white"; style: Text.Outline; styleColor: "black"; font.pixelSize: 15
        z: 100
        SequentialAnimation on opacity { id: hintFade; running: true
            PauseAnimation { duration: 3500 } NumberAnimation { to: 0; duration: 800 } }
    }

    // Screenshot mode: cycle through all themes, save PNGs, quit.
    Timer {
        interval: 2200; repeat: true; running: win.shotsDir !== ""
        onTriggered: {
            ld.grabToImage(function (r) {
                r.saveToFile(win.shotsDir + "/" + (win.idx < 9 ? "0" : "") + (win.idx + 1) + "_" + win.themes[win.idx] + ".png")
                if (win.idx === win.themes.length - 1) Qt.quit(); else win.idx++
            })
        }
    }
}
