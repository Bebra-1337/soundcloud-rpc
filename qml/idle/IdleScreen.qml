import QtQuick

// Host for the idle themes: the app sets these properties, the selected theme scene only draws them.
//
// Colors: the app's scheme (`bg`, `ink`, `accent`, from Style: the system palette or SoundCloud's dark / light) is
// handed down as the item palette, which every item of the theme inherits: `palette.window` is the background,
// `palette.windowText` the text, `palette.accent` marks progress and music, `palette.highlightedText` is text on
// the accent, `palette.shadow` darkens (vignettes, shadows). The text is pushed toward white / black until it
// stands out from the background at 7:1, because this screen is read from across the room.
Item {
    id: host

    property string theme: "GlassCard"
    property bool active: false
    property string title: ""
    property string artist: ""
    property url cover: ""
    property real syncPosition: 0  // player position in seconds, reported a few times a second
    property real position: 0      // smooth position shown by the themes
    property real duration: 1
    property bool playing: true
    property real audioBass: 0
    property real audioMid: 0
    property real audioTreble: 0
    property real audioLevel: 0
    property var audioBands: []
    property var audioBandsL: []
    property var audioBandsR: []

    // the player's state for the themes' controls, and the requests they send
    property bool liked: false
    property bool shuffle: false
    property int repeatMode: 0
    property real volume: 1
    property bool muted: false
    signal togglePlayRequested()
    signal nextRequested()
    signal previousRequested()
    signal seekRequested(real seconds)
    signal likeRequested()
    signal shuffleRequested()
    signal repeatRequested()
    signal volumeRequested(real value)
    signal muteRequested()
    signal controlsUsed()   // any of the above

    property color bg: "#121212"
    property color ink: "#fafafa"
    property color accent: "#ff5500"
    readonly property alias loadedItem: ld.item

    function lum(c) {
        c = Qt.color(c)
        function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }
    function contrast(a, b) {
        const la = lum(a), lb = lum(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }
    function mix(a, b, t) {
        a = Qt.color(a); b = Qt.color(b)
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }
    // fg moved toward black or white (whichever is away from bg) just far enough to reach the ratio
    function readable(fg, back, ratio) {
        const target = lum(back) > 0.18 ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1)
        for (let t = 0; t < 1; t += 0.05) {
            const c = mix(fg, target, t)
            if (contrast(c, back) >= ratio)
                return c
        }
        return target
    }
    readonly property bool light: lum(bg) > 0.18
    readonly property color displayInk: readable(ink, bg, 7)
    // an accent too close to the background (a gray system accent on gray) is lifted like the text, but less
    readonly property color displayAccent: readable(accent, bg, 3)

    palette.window: bg
    palette.windowText: displayInk
    palette.accent: displayAccent
    palette.highlightedText: contrast(displayAccent, "#000000") > contrast(displayAccent, "#ffffff") ? "#000000" : "#ffffff"
    palette.shadow: light ? mix(bg, "#000000", 0.55) : "#000000"

    // the typefaces of the themes (IdleText picks them by family name)
    FontLoader { source: "qrc:/fonts/InterVariable.ttf" }
    FontLoader { source: "qrc:/fonts/CormorantGaramond-Medium.otf" }
    FontLoader { source: "qrc:/fonts/CormorantGaramond-MediumItalic.otf" }

    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 700 } }

    Rectangle { anchors.fill: parent; color: host.bg }

    // Between the player's reports the position is extrapolated from the last one, so bars and digits move
    // smoothly whatever the report rate is.
    property double anchorMs: 0
    property real anchorPos: 0
    function reanchor(p) {
        anchorPos = p
        anchorMs = Date.now()
        position = Math.min(duration, p)
    }
    onSyncPositionChanged: reanchor(syncPosition)
    onPlayingChanged: reanchor(syncPosition)
    onActiveChanged: if (active) reanchor(syncPosition)
    Timer {
        interval: 200; repeat: true; running: host.active && host.playing
        onTriggered: host.position = Math.min(host.duration, host.anchorPos + (Date.now() - host.anchorMs) / 1000)
    }

    // Unloaded while inactive, so hidden themes cost no rendering or animation time.
    // Above whatever the host puts in this item (Main.qml's close-on-click area): presses on a control are taken by
    // it, presses anywhere else fall through and close the screen.
    Loader {
        id: ld
        z: 1
        anchors.fill: parent
        active: host.active
        source: "themes/" + host.theme + ".qml"
    }
    Binding { target: ld.item; property: "title"; value: host.title; when: ld.item }
    Binding { target: ld.item; property: "artist"; value: host.artist; when: ld.item }
    Binding { target: ld.item; property: "cover"; value: host.cover; when: ld.item }
    Binding { target: ld.item; property: "position"; value: host.position; when: ld.item }
    Binding { target: ld.item; property: "duration"; value: host.duration; when: ld.item }
    Binding { target: ld.item; property: "playing"; value: host.playing; when: ld.item }
    Binding { target: ld.item; property: "liked"; value: host.liked; when: ld.item }
    Binding { target: ld.item; property: "shuffle"; value: host.shuffle; when: ld.item }
    Binding { target: ld.item; property: "repeatMode"; value: host.repeatMode; when: ld.item }
    Binding { target: ld.item; property: "volume"; value: host.volume; when: ld.item }
    Binding { target: ld.item; property: "muted"; value: host.muted; when: ld.item }
    Connections {
        target: ld.item
        ignoreUnknownSignals: true
        function onRequestTogglePlay() { host.controlsUsed(); host.togglePlayRequested() }
        function onRequestNext() { host.controlsUsed(); host.nextRequested() }
        function onRequestPrevious() { host.controlsUsed(); host.previousRequested() }
        function onRequestSeek(seconds) { host.controlsUsed(); host.seekRequested(seconds) }
        function onRequestLike() { host.controlsUsed(); host.likeRequested() }
        function onRequestShuffle() { host.controlsUsed(); host.shuffleRequested() }
        function onRequestRepeat() { host.controlsUsed(); host.repeatRequested() }
        function onRequestVolume(value) { host.controlsUsed(); host.volumeRequested(value) }
        function onRequestMute() { host.controlsUsed(); host.muteRequested() }
    }
    Binding { target: ld.item; property: "audioBands"; value: host.audioBands; when: ld.item }
    Binding { target: ld.item; property: "audioBandsL"; value: host.audioBandsL; when: ld.item }
    Binding { target: ld.item; property: "audioBandsR"; value: host.audioBandsR; when: ld.item }
    // audioLevel is bound last: the theme feeds its reactor when it changes, after the other bands are in
    Binding { target: ld.item; property: "audioBass"; value: host.audioBass; when: ld.item }
    Binding { target: ld.item; property: "audioMid"; value: host.audioMid; when: ld.item }
    Binding { target: ld.item; property: "audioTreble"; value: host.audioTreble; when: ld.item }
    Binding { target: ld.item; property: "audioLevel"; value: host.audioLevel; when: ld.item }
}
