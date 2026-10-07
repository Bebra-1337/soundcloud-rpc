import QtQuick
import QtQuick.Shapes
import ScBackend

// Artwork with rounded (or circular) corners and a placeholder while loading or when there is none.
//
// The rounded shape is a Shape filled with the image's own texture (ShapePath.fillItem), not a MultiEffect
// mask: a mask is a layer of an invisible item, and such layers came back empty (black squares) after the
// page holding them was hidden and shown again (switching tabs). The fill texture is placed in its native
// pixels at the shape's origin, so fillTransform scales and centers it like Image.PreserveAspectCrop.
Item {
    id: art

    property url source
    property url fallback      // shown when the artwork itself can't be loaded (the uploader's avatar)
    property real radius: 4
    property bool round: false
    readonly property real cornerRadius: round ? Math.min(width, height) / 2 : radius

    // sndcdn.com does not render every size of every image, and some artwork URLs point at nothing at all:
    // try the other common sizes, then the fallback, then give up and keep the placeholder.
    readonly property var candidates: {
        const out = []
        const add = (u) => { if (u && out.indexOf(u) < 0 && !Style.missingArt[u]) out.push(u) }
        const variants = (u) => {
            add(u)
            const m = u.match(/-(t\d+x\d+|large|crop)\.(jpg|jpeg|png)$/)
            if (m) {
                for (const size of ["t500x500", "large"])
                    add(u.slice(0, m.index) + "-" + size + "." + m[2])
            }
        }
        variants("" + source)
        variants("" + fallback)
        return out
    }
    property int attempt: 0
    // An error is not always a missing image: the CDN sometimes closes its HTTP/2 connection while covers are
    // still loading over it ("Connection closed"). A URL the server answered with 4xx moves on to the next
    // candidate at once; one that failed in transit is retried (twice) before it counts as missing.
    readonly property var retryDelays: [1500, 5000]
    property int retries: 0
    property bool waiting: false
    onCandidatesChanged: {
        attempt = 0
        retries = 0
        waiting = false
        retryTimer.stop()
    }
    Timer {
        id: retryTimer
        onTriggered: art.waiting = false
    }
    // the URL that actually loaded (a fallback size or the avatar), empty while loading or when none did
    readonly property url resolved: img.status === Image.Ready ? img.source : ""

    Rectangle {
        anchors.fill: parent
        radius: art.cornerRadius
        color: Style.raised
        visible: img.status !== Image.Ready
        Icon {
            anchors.centerIn: parent
            name: art.round ? "user" : "note"
            size: Math.min(parent.width, parent.height) * 0.42
            color: Style.inkFaint
        }
    }
    Image {
        id: img
        visible: false  // only the texture provider for the shape below
        source: !art.waiting && art.attempt < art.candidates.length ? art.candidates[art.attempt] : ""
        onStatusChanged: {
            if (status !== Image.Error)
                return
            if (!App.isGone("" + source) && art.retries < art.retryDelays.length) {
                // the source goes empty and comes back, which loads it again
                retryTimer.interval = art.retryDelays[art.retries++]
                art.waiting = true
                retryTimer.start()
                return
            }
            Style.missingArt["" + source] = true
            art.retries = 0
            art.attempt++
        }
        sourceSize.width: Math.ceil(art.width * 2)
        sourceSize.height: Math.ceil(art.height * 2)
        asynchronous: true
        smooth: true
        mipmap: true
    }
    Shape {
        anchors.fill: parent
        visible: img.status === Image.Ready
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            readonly property real tw: Math.max(1, img.implicitWidth)
            readonly property real th: Math.max(1, img.implicitHeight)
            readonly property real s: Math.max(art.width / tw, art.height / th)
            strokeWidth: -1
            strokeColor: "transparent"
            fillItem: img
            fillTransform: PlanarTransform.fromAffineMatrix(s, 0, 0, s, (art.width - tw * s) / 2, (art.height - th * s) / 2)
            PathRectangle { x: 0; y: 0; width: art.width; height: art.height; radius: art.cornerRadius }
        }
    }
}
