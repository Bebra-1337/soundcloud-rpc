qt_add_library(scidle STATIC)

set(theme_files
    themes/ThemeBase.qml themes/TrackInfo.qml themes/Cover.qml themes/Progress.qml themes/Grain.qml
    themes/Vignette.qml themes/BlurBackdrop.qml themes/Shadow.qml themes/Marquee.qml
    themes/GlassCard.qml themes/BlurCover.qml themes/Aurora.qml themes/Vinyl.qml themes/Cassette.qml
    themes/Particles.qml themes/Equalizer.qml themes/Stereo.qml themes/Polaroid.qml themes/MinimalClock.qml
    themes/Typography.qml themes/Neon.qml themes/AlbumWall.qml themes/Orbit.qml themes/Starfield.qml
    themes/NowPlaying.qml themes/Ring.qml)

qt_add_qml_module(scidle
    URI SoundCloudRpc.Idle
    VERSION 1.0
    QML_FILES IdleScreen.qml Preview.qml ${theme_files}
    # the themes are loaded by URL ("themes/<Name>.qml"), not by type, and pull in each other through the
    # implicit directory import; their own linting is not part of this module's contract
    NO_LINT
)

# The app icon doubles as the preview's default cover (qrc:/soundcloud.png).
qt_add_resources(scidle "app_assets"
    PREFIX "/"
    BASE "${PROJECT_SOURCE_DIR}"
    FILES "${PROJECT_SOURCE_DIR}/soundcloud.png")

target_link_libraries(scidle PRIVATE Qt6::Quick)
