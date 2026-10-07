import QtQuick
import QtQuick.Shapes

// Line icons drawn from SVG paths on a 24x24 grid (no icon font or image plugin needed).
Item {
    id: icon

    property string name
    property color color: Style.ink
    property real size: 20
    property bool filled: false  // fill outline icons too (a liked heart)

    implicitWidth: size
    implicitHeight: size

    readonly property var icons: ({
        home: { d: "M4 10.5 L12 4 L20 10.5 V20 H14.5 V14 H9.5 V20 H4 Z" },
        feed: { d: "M5 6.5 H19 M5 12 H19 M5 17.5 H13" },
        library: { d: "M5 4.5 V19.5 M10 4.5 V19.5 M14.5 5.5 L19 19" },
        search: { d: "M4 10.5 A6.5 6.5 0 1 0 17 10.5 A6.5 6.5 0 1 0 4 10.5 M15.5 15.5 L20 20" },
        back: { d: "M14.5 5 L7.5 12 L14.5 19" },
        left: { d: "M14.5 5 L7.5 12 L14.5 19" },
        right: { d: "M9.5 5 L16.5 12 L9.5 19" },
        play: { fill: true, d: "M7.5 4.8 C7.5 4.1 8.3 3.7 8.9 4.1 L19.2 11.2 C19.7 11.6 19.7 12.4 19.2 12.8 L8.9 19.9 C8.3 20.3 7.5 19.9 7.5 19.2 Z" },
        pause: { fill: true, d: "M6.5 5 H10 V19 H6.5 Z M14 5 H17.5 V19 H14 Z" },
        next: { fill: true, d: "M5.5 5.5 C5.5 4.9 6.2 4.5 6.7 4.9 L15 11.2 C15.5 11.6 15.5 12.4 15 12.8 L6.7 19.1 C6.2 19.5 5.5 19.1 5.5 18.5 Z M17 5 H19 V19 H17 Z" },
        prev: { fill: true, d: "M18.5 5.5 C18.5 4.9 17.8 4.5 17.3 4.9 L9 11.2 C8.5 11.6 8.5 12.4 9 12.8 L17.3 19.1 C17.8 19.5 18.5 19.1 18.5 18.5 Z M5 5 H7 V19 H5 Z" },
        shuffle: { d: "M3.5 7 H7 C11 7 13 17 17 17 H20.5 M17.5 14 L20.5 17 L17.5 20 M3.5 17 H7 C8.6 17 9.8 15.4 10.8 13.5 M13.2 10.5 C14.2 8.6 15.4 7 17 7 H20.5 M17.5 4 L20.5 7 L17.5 10" },
        repeat: { d: "M17 3.5 L20 6.5 L17 9.5 M4 11.5 V10 A3.5 3.5 0 0 1 7.5 6.5 H20 M7 20.5 L4 17.5 L7 14.5 M20 12.5 V14 A3.5 3.5 0 0 1 16.5 17.5 H4" },
        heart: { d: "M12 19.5 C12 19.5 3.5 14.6 3.5 9 A4.5 4.5 0 0 1 12 6.8 A4.5 4.5 0 0 1 20.5 9 C20.5 14.6 12 19.5 12 19.5 Z" },
        volume: { d: "M4 9.5 H7.5 L12 5.5 V18.5 L7.5 14.5 H4 Z M15.5 9 A4 4 0 0 1 15.5 15 M18 6.5 A7.5 7.5 0 0 1 18 17.5" },
        volumeLow: { d: "M4 9.5 H7.5 L12 5.5 V18.5 L7.5 14.5 H4 Z M15.5 9 A4 4 0 0 1 15.5 15" },
        mute: { d: "M4 9.5 H7.5 L12 5.5 V18.5 L7.5 14.5 H4 Z M16 9.5 L21 14.5 M21 9.5 L16 14.5" },
        queue: { d: "M4 6 H20 M4 11 H20 M4 16 H12 M15.5 14 L20.5 17 L15.5 20 Z" },
        screen: { d: "M4.5 5 H19.5 A1.5 1.5 0 0 1 21 6.5 V15.5 A1.5 1.5 0 0 1 19.5 17 H4.5 A1.5 1.5 0 0 1 3 15.5 V6.5 A1.5 1.5 0 0 1 4.5 5 Z M10 8.5 V13.5 L14.5 11 Z M8 20.5 H16" },
        external: { d: "M14 4 H20 V10 M20 4 L11 13 M18 13.5 V19 A1 1 0 0 1 17 20 H5 A1 1 0 0 1 4 19 V7 A1 1 0 0 1 5 6 H10.5" },
        lock: { d: "M6.5 11 H17.5 V20 H6.5 Z M8.5 11 V8 A3.5 3.5 0 0 1 15.5 8 V11" },
        refresh: { d: "M19.5 12 A7.5 7.5 0 1 1 17.3 6.7 M19.5 4 V8 H15.5" },
        user: { d: "M8.5 8 A3.5 3.5 0 1 0 15.5 8 A3.5 3.5 0 1 0 8.5 8 M5 20 A7 7 0 0 1 19 20" },
        note: { d: "M9 17 V5.5 L19 3.5 V15 M4 17 A2.5 2.5 0 1 0 9 17 A2.5 2.5 0 1 0 4 17 M14 15 A2.5 2.5 0 1 0 19 15 A2.5 2.5 0 1 0 14 15" },
        close: { d: "M6 6 L18 18 M18 6 L6 18" },
        link: { d: "M10 14 L14 10 M8.5 11.5 L6.5 13.5 A3.5 3.5 0 0 0 11.5 18.5 L13.5 16.5 M15.5 12.5 L17.5 10.5 A3.5 3.5 0 0 0 12.5 5.5 L10.5 7.5" }
    })
    readonly property var def: icons[name] || { d: "" }

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: icon.def.fill ? "transparent" : icon.color
            strokeWidth: icon.def.fill ? -1 : 1.9
            fillColor: icon.def.fill || icon.filled ? icon.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.def.d }
        }
    }
}
