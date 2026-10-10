qt_add_library(scidle STATIC)

set(theme_files
    themes/ThemeBase.qml themes/TrackInfo.qml themes/Cover.qml themes/Progress.qml
    themes/BlurBackdrop.qml themes/Shadow.qml
    themes/GlassCard.qml themes/BlurCover.qml themes/Aurora.qml themes/Vinyl.qml themes/Cassette.qml
    themes/Particles.qml themes/Equalizer.qml themes/Stereo.qml themes/Polaroid.qml themes/MinimalClock.qml
    themes/Typography.qml themes/Neon.qml themes/AlbumWall.qml themes/Orbit.qml themes/Starfield.qml
    themes/NowPlaying.qml themes/Ring.qml themes/IdleText.qml themes/Glow.qml
    themes/IdleIcon.qml themes/IdleButton.qml themes/Controls.qml themes/VolumeSlider.qml
    themes/LiquidGlass.qml themes/GlassSource.qml themes/GlassKnob.qml)

qt_add_qml_module(scidle
    URI SoundCloudRpc.Idle
    VERSION 1.0
    QML_FILES IdleScreen.qml Preview.qml ${theme_files}
    # the themes are loaded by URL ("themes/<Name>.qml"), not by type, and pull in each other through the
    # implicit directory import; their own linting is not part of this module's contract
    NO_LINT
)

# Shaders of the themes, compiled at build time into .qsb (SPIR-V plus GLSL/HLSL/MSL) next to the QML files that load
# them by relative URL ("shaders/glass.frag.qsb" from themes/).
qt_add_shaders(scidle "idle_shaders"
    PREFIX "/qt/qml/SoundCloudRpc/Idle"
    FILES themes/shaders/glass.frag)

# App assets referenced from QML/C++ as qrc:/soundcloud.png (OS/tray icon, preview cover) and qrc:/logo.png /
# qrc:/logo-dark.png (the glyph shown in the rail and the sign-in panel, white for dark and black for light colors).
qt_add_resources(scidle "app_assets"
    PREFIX "/"
    BASE "${PROJECT_SOURCE_DIR}"
    FILES "${PROJECT_SOURCE_DIR}/soundcloud.png" "${PROJECT_SOURCE_DIR}/logo.png"
          "${PROJECT_SOURCE_DIR}/logo-dark.png")

# Typefaces of the idle screen (SIL Open Font License, texts next to the files): Inter as a variable font (weight and
# optical size are set through font.variableAxes; font.weight does not reach the axes of an application font) and
# Cormorant Garamond for the analog themes. Loaded by IdleScreen.
qt_add_resources(scidle "idle_fonts"
    PREFIX "/"
    FILES fonts/InterVariable.ttf fonts/CormorantGaramond-Medium.otf fonts/CormorantGaramond-MediumItalic.otf)

target_link_libraries(scidle PRIVATE Qt6::Quick)
