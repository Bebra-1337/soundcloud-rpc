import QtQuick

// A row of filter chips: [{ key, label }, ...].
Row {
    id: bar

    property var chips: []
    property string current
    signal picked(string key)

    spacing: 8

    Repeater {
        model: bar.chips
        Chip {
            required property var modelData
            text: modelData.label
            active: modelData.key === bar.current
            onClicked: bar.picked(modelData.key)
        }
    }
}
