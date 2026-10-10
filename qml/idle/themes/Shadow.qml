import QtQuick
import QtQuick.Effects

// Soft drop shadow of a rounded rectangle of the item's size, in two layers like a real one: a tight contact shadow
// right under the edges and a wide, faint one cast further down. Weaker on light schemes, where a full black shadow
// looks like dirt. `knockout` cuts the shadow out under the shape itself, for translucent things (glass) that would
// otherwise show their own shadow through.
Item {
    id: sh
    property real radius: 0
    property real offsetY: height * 0.05   // how far the wide shadow falls
    property real strength: 0.6
    property real blurMax: 64
    property bool knockout: false
    readonly property real k: strength * (0.2126 * palette.window.r + 0.7152 * palette.window.g + 0.0722 * palette.window.b > 0.45 ? 0.6 : 1)
    readonly property real m: blurMax + offsetY    // room around the shape for the blur

    Rectangle { id: src; width: sh.width; height: sh.height; radius: sh.radius; color: palette.shadow; visible: false; layer.enabled: true }

    Item {
        id: cast
        x: -sh.m; y: -sh.m
        width: sh.width + 2 * sh.m; height: sh.height + 2 * sh.m
        layer.enabled: sh.knockout
        layer.effect: MultiEffect { maskEnabled: true; maskInverted: true; maskSource: hole }
        MultiEffect {
            source: src
            x: sh.m; y: sh.m + Math.max(1, sh.height * 0.006); width: sh.width; height: sh.height
            blurEnabled: true; blur: 0.3; blurMax: 24
            opacity: 0.45 * sh.k
        }
        MultiEffect {
            source: src
            x: sh.m + sh.width * 0.04; y: sh.m + sh.offsetY + sh.height * 0.02; width: sh.width * 0.92; height: sh.height * 0.96
            blurEnabled: true; blur: 1.0; blurMax: sh.blurMax
            opacity: 0.75 * sh.k
        }
    }
    // the shape, at the same place in the cast's coordinates, as the knockout mask
    Item {
        id: hole
        width: cast.width; height: cast.height
        visible: false
        layer.enabled: sh.knockout
        layer.smooth: true
        Rectangle { x: sh.m; y: sh.m; width: sh.width; height: sh.height; radius: sh.radius; color: "black"; antialiasing: true }
    }
}
