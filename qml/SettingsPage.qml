import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import ScBackend

// Settings: colors and language on the left, the idle screen (when it opens, which theme) on the right.
Item {
    id: root

    readonly property var colorHints: ({
        auto: App.systemPaletteDefault ? "Uses your desktop's color scheme." : "SoundCloud's dark colors.",
        system: App.systemPaletteDefault ? "Your desktop's color scheme (qt6ct), updated live."
                                         : "The Qt color scheme of the system.",
        dark: "SoundCloud's dark colors.",
        light: "SoundCloud's light colors."
    })

    PageHeader {
        id: header
        page: root
        width: parent.width
        title: "Settings"
    }

    Flickable {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        contentHeight: grid.implicitHeight + Style.gutter
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        GridLayout {
            id: grid
            x: Style.gutter
            width: parent.width - 2 * Style.gutter
            columns: width >= 760 ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: grid.columns > 1 ? 410 : grid.width
                Layout.fillWidth: grid.columns === 1
                spacing: 16

                Card {
                    title: "Theme"
                    ChipFlow {
                        chips: App.colorModes
                        current: App.colorMode
                        onPicked: (key) => App.colorMode = key
                    }
                    Hint { text: root.colorHints[App.colorMode] || "" }

                    Text {
                        Layout.topMargin: 4
                        text: "Logo"
                        color: Style.inkDim
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Row {
                        spacing: 8
                        LogoTile { key: "auto"; label: "Automatic" }
                        LogoTile { key: "white"; label: "White" }
                        LogoTile { key: "black"; label: "Black" }
                    }
                }

                Card {
                    title: "Language"
                    ChipFlow {
                        chips: App.languages
                        current: App.language
                        onPicked: (key) => App.language = key
                    }
                    Hint { text: "Translations aren't ready yet: the interface stays in English for now." }
                }
            }

            Card {
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                title: "Idle screen"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: "Open by itself while music plays and the app isn't touched"
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
                        text: "After"
                        color: Style.inkDim
                        font.pixelSize: 13
                    }
                    Slider {
                        id: delaySlider
                        Layout.fillWidth: true
                        from: App.idleDelayMin
                        to: App.idleDelayMax
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: App.idleDelay
                        onMoved: App.idleDelay = Math.round(value)
                        background: Rectangle {
                            x: delaySlider.leftPadding
                            y: delaySlider.topPadding + delaySlider.availableHeight / 2 - height / 2
                            width: delaySlider.availableWidth
                            height: 4
                            radius: 2
                            color: Style.outline
                            Rectangle {
                                width: delaySlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: Style.accent
                            }
                        }
                        handle: Rectangle {
                            x: delaySlider.leftPadding + delaySlider.visualPosition * (delaySlider.availableWidth - width)
                            y: delaySlider.topPadding + delaySlider.availableHeight / 2 - height / 2
                            width: 14
                            height: 14
                            radius: 7
                            color: Style.accent
                            scale: delaySlider.pressed ? 1.15 : 1
                            Behavior on scale { NumberAnimation { duration: 100 } }
                        }
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
                        text: "sec"
                        color: Style.inkDim
                        font.pixelSize: 13
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Text {
                        Layout.fillWidth: true
                        text: "Style"
                        color: Style.inkDim
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Chip {
                        text: "Preview"
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
