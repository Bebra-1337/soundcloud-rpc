import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import ScBackend

// Settings in three tabs: General (colors, logo, language), Idle screen (when it opens, which theme) and Storage
// (the disk cache).
Item {
    id: root

    property string tab: "general"
    readonly property var tabs: [
        { key: "general", label: qsTr("General") },
        { key: "idle", label: qsTr("Idle screen") },
        { key: "storage", label: qsTr("Storage") }
    ]

    readonly property var colorHints: ({
        auto: App.systemPaletteDefault ? qsTr("Uses your desktop's color scheme.") : qsTr("SoundCloud's dark colors."),
        system: App.systemPaletteDefault ? qsTr("Your desktop's color scheme (qt6ct), updated live.")
                                         : qsTr("The Qt color scheme of the system."),
        dark: qsTr("SoundCloud's dark colors."),
        light: qsTr("SoundCloud's light colors.")
    })

    function fmtBytes(b) {
        if (b < 0)
            return "…"
        const mb = b / (1024 * 1024)
        if (mb >= 1024)
            return qsTr("%1 GB").arg((mb / 1024).toFixed(1))
        if (mb >= 10)
            return qsTr("%1 MB").arg(Math.round(mb))
        return mb >= 0.1 ? qsTr("%1 MB").arg(mb.toFixed(1)) : qsTr("%1 KB").arg(Math.round(b / 1024))
    }
    function fmtLimit(mb) {
        return mb >= 1000 ? qsTr("%1 GB").arg((mb / 1000).toFixed(mb % 1000 === 0 ? 0 : 1)) : qsTr("%1 MB").arg(mb)
    }

    // the size is counted when the tab is shown (it changes while browsing, not while looking at it)
    readonly property bool storageShown: visible && tab === "storage"
    onStorageShownChanged: if (storageShown) App.refreshCacheSize()

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: qsTr("Settings")
    }

    ChipBar {
        id: tabBar
        anchors.top: header.bottom
        x: Style.gutter
        chips: root.tabs
        current: root.tab
        onPicked: (key) => root.tab = key
    }

    Flickable {
        anchors.top: tabBar.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        width: parent.width
        contentHeight: pages.height + Style.gutter
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Item {
            id: pages
            x: Style.gutter
            width: parent.width - 2 * Style.gutter
            height: general.visible ? general.implicitHeight : idle.visible ? idle.implicitHeight : storage.implicitHeight

            Flow {
                id: general
                visible: root.tab === "general"
                width: parent.width
                spacing: 16

                Card {
                    width: Math.min(410, general.width)
                    title: qsTr("Theme")
                    ChipFlow {
                        chips: App.colorModes
                        current: App.colorMode
                        onPicked: (key) => App.colorMode = key
                    }
                    Hint { text: root.colorHints[App.colorMode] || "" }

                    Text {
                        Layout.topMargin: 4
                        text: qsTr("Logo")
                        color: Style.inkDim
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Row {
                        spacing: 8
                        LogoTile { key: "auto"; label: qsTr("Automatic") }
                        LogoTile { key: "white"; label: qsTr("White") }
                        LogoTile { key: "black"; label: qsTr("Black") }
                    }
                }

                Card {
                    width: Math.min(410, general.width)
                    title: qsTr("Language")
                    ChipFlow {
                        chips: App.languages
                        current: App.language
                        onPicked: (key) => App.language = key
                    }
                    Hint { text: qsTr("System uses your desktop's language, or English when there is no translation for it.") }
                }
            }

            ColumnLayout {
                id: idle
                visible: root.tab === "idle"
                width: Math.min(parent.width, 760)

                Card {
                    title: qsTr("Idle screen")

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Open by itself while music plays and the app isn't touched")
                            color: Style.ink
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Toggle {
                            checked: App.idleAuto
                            onToggled: App.idleAuto = checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        enabled: App.idleAuto
                        opacity: enabled ? 1 : 0.45
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Text {
                            //: "After [slider] 30 sec": the delay before the idle screen opens
                            text: qsTr("After")
                            color: Style.inkDim
                            font.pixelSize: 13
                        }
                        AccentSlider {
                            Layout.fillWidth: true
                            from: App.idleDelayMin
                            to: App.idleDelayMax
                            stepSize: 1
                            value: App.idleDelay
                            onMoved: App.idleDelay = Math.round(value)
                        }
                        TextField {
                            id: delayField
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 32
                            horizontalAlignment: TextInput.AlignHCenter
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 0; top: App.idleDelayMax }
                            color: Style.ink
                            selectionColor: Style.hover
                            selectByMouse: true
                            font.pixelSize: 13
                            background: Rectangle {
                                radius: 8
                                color: Style.raised
                                border.color: delayField.activeFocus ? Style.inkFaint : "transparent"
                            }
                            // not bound: typing must not be overwritten, and a value outside the range snaps back
                            function sync() { text = App.idleDelay }
                            Component.onCompleted: sync()
                            Connections {
                                target: App
                                function onIdleDelayChanged() { if (!delayField.activeFocus) delayField.sync() }
                            }
                            onEditingFinished: {
                                App.idleDelay = parseInt(text) || App.idleDelayMin
                                sync()
                            }
                            onActiveFocusChanged: if (!activeFocus) sync()
                            Keys.onEscapePressed: { sync(); focus = false }
                        }
                        Text {
                            //: seconds, after the delay field
                            text: qsTr("sec")
                            color: Style.inkDim
                            font.pixelSize: 13
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Text {
                            Layout.fillWidth: true
                            //: heading above the idle screen's themes
                            text: qsTr("Style")
                            color: Style.inkDim
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        Chip {
                            text: qsTr("Preview")
                            enabled: Player.hasTrack
                            opacity: enabled ? 1 : 0.45
                            onClicked: App.showIdle()
                        }
                    }
                    ChipFlow {
                        chips: App.idleThemes
                        current: App.idleTheme
                        onPicked: (key) => App.idleTheme = key
                    }
                }
            }

            ColumnLayout {
                id: storage
                visible: root.tab === "storage"
                width: Math.min(parent.width, 620)

                Card {
                    title: qsTr("Cache")

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: root.fmtBytes(App.cacheSize)
                                color: Style.ink
                                font.pixelSize: 24
                                font.weight: Font.Bold
                            }
                            Text {
                                //: under the cache size, e.g. "120 MB / in use"
                                text: qsTr("in use")
                                color: Style.inkDim
                                font.pixelSize: 12
                            }
                        }
                        // two clicks: the first asks, the second clears; the question goes away after a few seconds
                        Chip {
                            id: clearButton
                            property bool confirming: false
                            text: confirming ? qsTr("Are you sure?") : qsTr("Clear cache")
                            active: confirming
                            onClicked: {
                                if (confirming) {
                                    confirming = false
                                    App.clearCache()
                                } else {
                                    confirming = true
                                    confirmTimeout.restart()
                                }
                            }
                            Timer {
                                id: confirmTimeout
                                interval: 4000
                                onTriggered: clearButton.confirming = false
                            }
                            Connections {
                                target: root
                                function onStorageShownChanged() { clearButton.confirming = false }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 12
                        Text {
                            //: the cache size limit slider
                            text: qsTr("Limit")
                            color: Style.inkDim
                            font.pixelSize: 13
                        }
                        AccentSlider {
                            Layout.fillWidth: true
                            from: App.cacheLimitMin
                            to: App.cacheLimitMax
                            stepSize: 50
                            value: App.cacheLimit
                            onMoved: App.cacheLimit = Math.round(value)
                        }
                        Text {
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                            text: root.fmtLimit(App.cacheLimit)
                            color: Style.ink
                            font.pixelSize: 13
                        }
                    }

                    Hint {
                        text: qsTr("Covers, waveforms and the last Home, Feed and Library, so they open at once and also without a connection. When the covers reach the limit, the oldest are removed.")
                    }
                }
            }
        }
    }

    // The app's slider look: an accent fill on a thin track.
    component AccentSlider: Slider {
        id: slider
        snapMode: Slider.SnapAlways
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Style.outline
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Style.accent
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 14
            height: 14
            radius: 7
            color: Style.accent
            scale: slider.pressed ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }

    // A rounded panel with a title; its children are laid out in a column below the title.
    component Card: Rectangle {
        id: card
        property string title
        default property alias content: body.data
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 2 * 20
        radius: 14
        color: Style.panel
        border.color: Style.surface

        ColumnLayout {
            id: body
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 12
            Text {
                text: card.title
                color: Style.ink
                font.pixelSize: 15
                font.weight: Font.Bold
            }
        }
    }

    // A logo choice drawn as it looks: the white glyph on SoundCloud's black, the black one on its white, and for
    // automatic both halves.
    component LogoTile: Column {
        id: tile
        property string key
        property string label
        readonly property bool active: App.logoStyle === key
        spacing: 6

        Rectangle {
            width: 88
            height: 44
            radius: 10
            clip: true
            color: tile.key === "black" ? Style.brandWhite : Style.brandBlack
            border.width: 2
            border.color: tile.active ? Style.accent : (tileHover.hovered ? Style.outline : Style.surface)
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Rectangle {  // the light half of "automatic", inside the border
                visible: tile.key === "auto"
                x: parent.width / 2
                y: 2
                width: parent.width / 2 - 2
                height: parent.height - 4
                topRightRadius: parent.radius - 2
                bottomRightRadius: parent.radius - 2
                color: Style.brandWhite
            }
            Row {
                anchors.centerIn: parent
                spacing: tile.key === "auto" ? 14 : 0
                Image {
                    visible: tile.key !== "black"
                    width: tile.key === "auto" ? 26 : 40
                    height: width * 184 / 408
                    source: "qrc:/logo.png"
                    sourceSize: Qt.size(width * 2, height * 2)
                    smooth: true
                }
                Image {
                    visible: tile.key !== "white"
                    width: tile.key === "auto" ? 26 : 40
                    height: width * 184 / 408
                    source: "qrc:/logo-dark.png"
                    sourceSize: Qt.size(width * 2, height * 2)
                    smooth: true
                }
            }
            HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: App.logoStyle = tile.key }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            color: tile.active ? Style.ink : Style.inkDim
            font.pixelSize: 12
        }
    }

    component Hint: Text {
        Layout.fillWidth: true
        color: Style.inkFaint
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    // Chips that wrap onto further lines: [{ key, label }, ...].
    component ChipFlow: Flow {
        id: flow
        property var chips: []
        property string current
        signal picked(string key)
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: flow.chips
            Chip {
                required property var modelData
                text: modelData.label
                active: modelData.key === flow.current
                onClicked: flow.picked(modelData.key)
            }
        }
    }

    component Toggle: Switch {
        id: sw
        padding: 0
        spacing: 0
        implicitWidth: 40
        implicitHeight: 22
        indicator: Rectangle {
            x: 0
            y: (sw.height - height) / 2
            width: 40
            height: 22
            radius: height / 2
            color: sw.checked ? Style.accent : Style.outline
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                x: sw.checked ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: sw.checked ? Style.onAccent : Style.ink
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }
        contentItem: Item { }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
}
