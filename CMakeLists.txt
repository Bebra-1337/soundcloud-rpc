cmake_minimum_required(VERSION 3.21)
project(soundcloud-rpc VERSION 2.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core Gui Widgets Network DBus Qml Quick QuickControls2 Multimedia WebEngineCore WebEngineWidgets)
qt_standard_project_setup(REQUIRES 6.8)

# Idle-screen themes: a static QML module shared by the app and the theme preview.
add_subdirectory(qml/idle)

qt_add_executable(soundcloud-rpc
    src/main.cpp
    src/app/Application.h src/app/Application.cpp
    src/app/ThemeWatcher.h src/app/ThemeWatcher.cpp
    src/api/ClientIdProvider.h src/api/ClientIdProvider.cpp
    src/api/SoundCloudApi.h src/api/SoundCloudApi.cpp
    src/api/AuthManager.h src/api/AuthManager.cpp
    src/api/Entities.h src/api/Entities.cpp
    src/api/WebProfile.h src/api/WebProfile.cpp
    src/api/WebSession.h src/api/WebSession.cpp
    src/models/PagedListModel.h src/models/PagedListModel.cpp
    src/player/PlayerController.h src/player/PlayerController.cpp
    src/player/AudioAnalyser.h src/player/AudioAnalyser.cpp
    src/integrations/DiscordIpc.h src/integrations/DiscordIpc.cpp
    src/integrations/DiscordPresence.h src/integrations/DiscordPresence.cpp
    src/integrations/Mpris.h src/integrations/Mpris.cpp
)
target_include_directories(soundcloud-rpc PRIVATE src)
target_compile_definitions(soundcloud-rpc PRIVATE PROJECT_VERSION="${PROJECT_VERSION}")

set(ui_qml
    Main.qml Style.qml Icon.qml IconButton.qml ArtImage.qml PlayingBars.qml Spinner.qml Rail.qml PageHeader.qml
    ChipBar.qml ItemRow.qml ItemList.qml ItemGrid.qml ItemMenu.qml Card.qml Shelf.qml Waveform.qml
    NowPlayingPanel.qml SignInPanel.qml Toast.qml
    HomePage.qml FeedPage.qml LibraryPage.qml SearchPage.qml PlaylistPage.qml UserPage.qml QueuePage.qml)
set(ui_qml_paths)
foreach(f IN LISTS ui_qml)
    # served from the module root, next to its qmldir, so the implicit directory import sees the Style singleton
    set_source_files_properties(qml/${f} PROPERTIES QT_RESOURCE_ALIAS ${f})
    list(APPEND ui_qml_paths qml/${f})
endforeach()
set_source_files_properties(qml/Style.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(soundcloud-rpc
    URI SoundCloudRpc
    VERSION 1.0
    QML_FILES ${ui_qml_paths}
)

target_link_libraries(soundcloud-rpc PRIVATE
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Network Qt6::DBus Qt6::Qml Qt6::Quick Qt6::QuickControls2
    Qt6::Multimedia Qt6::WebEngineCore Qt6::WebEngineWidgets
    scidleplugin)

# Standalone gallery of the idle themes with fake data (replaces qml/preview.py).
qt_add_executable(soundcloud-rpc-preview src/preview_main.cpp)
target_link_libraries(soundcloud-rpc-preview PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick scidleplugin)

install(TARGETS soundcloud-rpc soundcloud-rpc-preview RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
