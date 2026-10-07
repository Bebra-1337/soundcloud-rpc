cmake_minimum_required(VERSION 3.21)
project(soundcloud-rpc VERSION 2.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(qt_components Core Gui Widgets Network Qml Quick QuickControls2 Multimedia WebEngineCore WebEngineWidgets)
# MPRIS (D-Bus) and the qt6ct theme follower exist on Linux only
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    list(APPEND qt_components DBus)
endif()
find_package(Qt6 6.8 REQUIRED COMPONENTS ${qt_components})
qt_standard_project_setup(REQUIRES 6.8)

# Idle-screen themes: a static QML module shared by the app and the theme preview.
add_subdirectory(qml/idle)

qt_add_executable(soundcloud-rpc
    src/main.cpp
    src/app/Application.h src/app/Application.cpp
    src/app/QmlNetwork.h src/app/QmlNetwork.cpp
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
)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_sources(soundcloud-rpc PRIVATE
        src/app/ThemeWatcher.h src/app/ThemeWatcher.cpp
        src/integrations/Mpris.h src/integrations/Mpris.cpp)
endif()
target_include_directories(soundcloud-rpc PRIVATE src)
target_compile_definitions(soundcloud-rpc PRIVATE PROJECT_VERSION="${PROJECT_VERSION}")

set(ui_qml
    Main.qml Style.qml Icon.qml IconButton.qml Chip.qml ArtImage.qml PlayingBars.qml Spinner.qml Rail.qml PageHeader.qml
    ChipBar.qml ItemRow.qml ItemList.qml ItemGrid.qml ItemMenu.qml Card.qml Shelf.qml Waveform.qml
    NowPlayingPanel.qml SignInPanel.qml Toast.qml
    HomePage.qml FeedPage.qml LibraryPage.qml SearchPage.qml PlaylistPage.qml UserPage.qml QueuePage.qml
    SettingsPage.qml)
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
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Network Qt6::Qml Qt6::Quick Qt6::QuickControls2
    Qt6::Multimedia Qt6::WebEngineCore Qt6::WebEngineWidgets
    scidleplugin)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_link_libraries(soundcloud-rpc PRIVATE Qt6::DBus)
endif()

# Standalone gallery of the idle themes with fake data (replaces qml/preview.py).
qt_add_executable(soundcloud-rpc-preview src/preview_main.cpp)
target_link_libraries(soundcloud-rpc-preview PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick scidleplugin)

install(TARGETS soundcloud-rpc soundcloud-rpc-preview RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
