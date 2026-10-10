import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import ScBackend
import SoundCloudRpc.Idle

// Main window, designed for the 1431x500 banner it usually lives in: navigation rail, the current section's
// page stack, and the Now Playing column. The idle screen is an overlay over all of it.
ApplicationWindow {
    id: win

    width: 1431
    height: 500
    minimumWidth: 900
    minimumHeight: 420
    visible: false  // shown from C++ after the surface format is set (or not at all with --minimized)
    // Window managers match the title when a window maps (the user's Hyprland rule floats and places
    // "^SoundCloud Desktop$", which also tells it from the sign-in window), and a window shown again maps again:
    // keep the plain title until a second after it is shown, the track's only then. A queue restored from the last
    // session would otherwise put the track in the title before the very first map.
    property bool trackTitle: false
    onVisibleChanged: {
        trackTitle = false
        if (visible)
            trackTitleDelay.restart()
    }
    Timer { id: trackTitleDelay; interval: 1000; onTriggered: win.trackTitle = true }
    title: trackTitle && Player.hasTrack ? Player.current.title + " · " + Player.current.artist : "SoundCloud Desktop"
    color: Style.bg

    palette {
        window: Style.raised
        windowText: Style.ink
        base: Style.surface
        alternateBase: Style.raised
        text: Style.ink
        button: Style.raised
        buttonText: Style.ink
        brightText: Style.ink
        highlight: Style.hover
        highlightedText: Style.ink
        placeholderText: Style.inkFaint
        toolTipBase: Style.raised
        toolTipText: Style.ink
        light: Style.raised
        midlight: Style.hover
        mid: Style.outline
        dark: Style.inkDim
        shadow: "#000000"
    }

    readonly property var stacks: [homeStack, feedStack, libraryStack, searchStack, settingsStack]
    readonly property StackView currentStack: stacks[sections.currentIndex]

    function navigate(index) {
        if (sections.currentIndex === index && currentStack.depth > 1)
            currentStack.pop(null)  // clicking the current section again goes back to its root
        sections.currentIndex = index
    }

    function openItem(item) {
        if (!item || !item.kind)
            return
        if (item.kind === "track")
            Player.playTrack(item)
        else if (item.kind === "user")
            currentStack.push(userPage, { item: item })
        else
            currentStack.push(playlistPage, { item: item })
    }

    // play a playlist / album without opening it (card play buttons)
    function playCollection(item) {
        if (item.kind === "user") {
            openItem(item)
            return
        }
        Api.loadPlaylist(item.urn || item.id, (result, err) => {
            if (result && result.items.length > 0)
                Player.playList(result.items, 0, result.info.title)
            else
                toast.show(item.title ? qsTr("Couldn't load %1").arg(item.title) : qsTr("Couldn't load the playlist"))
        })
    }

    function showMenu(item) {
        itemMenu.openFor(item)
    }

    function openQueue() {
        if (currentStack.currentItem && currentStack.currentItem.objectName === "queue")
            return
        currentStack.push(queuePage)
    }

    Connections {
        target: App
        function onOpenItemRequested(item) { win.openItem(item) }
        function onPlayCollectionRequested(item) { win.playCollection(item) }
        function onMenuRequested(item) { win.showMenu(item) }
        function onToast(text) { toast.show(text) }
        function onSettingsRequested() { win.navigate(rail.settingsIndex) }
    }

    Component { id: playlistPage; PlaylistPage { } }
    Component { id: userPage; UserPage { } }
    Component { id: queuePage; QueuePage { objectName: "queue" } }

    Rail {
        id: rail
        z: 2  // above the sections: StackView push/pop slides pages out of their bounds, under the rail
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        current: sections.currentIndex
        onNavigate: (index) => win.navigate(index)
        onOpenMe: if (Api.ready) win.openItem(Api.me)
    }

    StackLayout {
        id: sections
        anchors.left: rail.right
        anchors.right: nowPlaying.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        StackView { id: homeStack; initialItem: HomePage { } }
        StackView { id: feedStack; initialItem: FeedPage { } }
        StackView { id: libraryStack; initialItem: LibraryPage { } }
        StackView { id: searchStack; initialItem: SearchPage { id: searchPage } }
        StackView { id: settingsStack; initialItem: SettingsPage { } }
    }

    SignInPanel {
        anchors.fill: sections
        visible: !Api.ready && sections.currentIndex !== rail.settingsIndex
    }

    NowPlayingPanel {
        id: nowPlaying
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onOpenQueue: win.openQueue()
        onOpenArtist: if (Player.current.userId > 0)
            win.openItem({ kind: "user", id: Player.current.userId, title: Player.current.artist })
    }

    ItemMenu { id: itemMenu }

    Toast {
        id: toast
        anchors.horizontalCenter: sections.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        z: 50
    }

    // Idle screen: a click or key press closes it (ignored right after opening, a double click on the button)
    IdleScreen {
        id: idle
        anchors.fill: parent
        z: 100
        visible: opacity > 0.001
        active: App.idleActive
        theme: App.idleTheme
        bg: Style.bg
        ink: Style.ink
        accent: Style.accent
        title: Player.current.title || ""
        artist: Player.current.artist || ""
        cover: nowPlaying.coverUrl
        syncPosition: Player.position / 1000
        duration: Math.max(1, Player.duration / 1000)
        playing: Player.playing
        audioBands: Analyser.bands
        audioBandsL: Analyser.bandsL
        audioBandsR: Analyser.bandsR
        audioBass: Analyser.bass
        audioMid: Analyser.mid
        audioTreble: Analyser.treble
        audioLevel: Analyser.level
        liked: Player.hasTrack && Api.likesRevision >= 0 && Api.isLiked(Player.current.id)
        shuffle: Player.shuffle
        repeatMode: Player.repeatMode
        volume: Player.volume
        muted: Player.muted
        onControlsUsed: App.idleInteracted()
        onTogglePlayRequested: Player.togglePlay()
        onNextRequested: Player.next()
        onPreviousRequested: Player.previous()
        onSeekRequested: (seconds) => Player.seek(seconds * 1000)
        onLikeRequested: if (Player.hasTrack) Api.setLiked(Player.current.id, !liked)
        onShuffleRequested: Player.shuffle = !Player.shuffle
        onRepeatRequested: Player.cycleRepeat()
        onVolumeRequested: (value) => { Player.volume = value; Player.muted = false }
        onMuteRequested: Player.muted = !Player.muted

        property double shownAt: 0
        onActiveChanged: if (active) {
            shownAt = Date.now()
            idleKeys.forceActiveFocus()
        }

        MouseArea {
            anchors.fill: parent
            enabled: App.idleActive
            acceptedButtons: Qt.AllButtons
            onPressed: if (Date.now() - idle.shownAt >= 400) App.idleActive = false
            onWheel: (wheel) => wheel.accepted = true
        }
        Item {
            id: idleKeys
            Keys.onPressed: (event) => {
                event.accepted = true
                if (Date.now() - idle.shownAt >= 400)
                    App.idleActive = false
            }
        }
    }

    Shortcut {
        sequence: "Space"
        enabled: !App.idleActive
        onActivated: Player.togglePlay()
    }
    Shortcut {
        sequences: ["Ctrl+F", "Ctrl+K"]
        enabled: !App.idleActive
        onActivated: {
            win.navigate(3)
            searchStack.pop(null)
            searchPage.focusField()
        }
    }
    Shortcut { sequence: "Ctrl+Shift+C"; onActivated: App.copyTrackLink() }
    Shortcut { sequence: "Ctrl+Right"; onActivated: Player.next() }
    Shortcut { sequence: "Ctrl+Left"; onActivated: Player.previous() }
    Shortcut { sequence: "Right"; enabled: !App.idleActive; onActivated: Player.seek(Player.position + 5000) }
    Shortcut { sequence: "Left"; enabled: !App.idleActive; onActivated: Player.seek(Player.position - 5000) }
    Shortcut { sequence: "Ctrl+L"; onActivated: if (Player.hasTrack) Api.setLiked(Player.current.id, !Api.isLiked(Player.current.id)) }
    Shortcut { sequence: "Ctrl+I"; onActivated: App.idleActive = !App.idleActive }
    Shortcut { sequence: "Ctrl+,"; enabled: !App.idleActive; onActivated: win.navigate(rail.settingsIndex) }
    Shortcut {
        sequences: ["Esc", "Alt+Left"]
        enabled: !App.idleActive
        onActivated: if (win.currentStack.depth > 1) win.currentStack.pop()
    }
}
