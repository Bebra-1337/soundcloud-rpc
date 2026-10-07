{
  lib,
  stdenv,
  cmake,
  ninja,
  qt6,
  makeDesktopItem,
  copyDesktopItems,
}:

stdenv.mkDerivation {
  pname = "soundcloud-rpc";
  version = "2.0.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./CMakeLists.txt
      ./src
      ./qml
      ./soundcloud.png
      ./logo.png
      ./logo-dark.png
    ];
  };

  nativeBuildInputs = [
    cmake
    ninja
    qt6.wrapQtAppsHook
    copyDesktopItems
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia # QMediaPlayer with the FFmpeg backend (HLS, QAudioBufferOutput for the visualiser)
    qt6.qtwebengine # only for the one-time sign-in window
    qt6.qtwayland
    qt6.qtsvg
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "soundcloud-rpc";
      desktopName = "SoundCloud Desktop";
      genericName = "Music Player";
      comment = "SoundCloud Desktop Player with Discord RPC and MPRIS Integration";
      exec = "soundcloud-rpc %U";
      icon = "soundcloud-rpc";
      terminal = false;
      type = "Application";
      categories = [
        "AudioVideo"
        "Audio"
        "Player"
        "Music"
      ];
      startupWMClass = "soundcloud-rpc";
      keywords = [
        "SoundCloud"
        "Music"
        "Player"
        "RPC"
        "Discord"
        "MPRIS"
      ];
    })
  ];

  postInstall = ''
    # hicolor's own index.theme only lists sizes up to 512x512 (then "scalable"); an icon dropped into
    # 1024x1024/apps sits outside every declared directory, so anything that looks the icon up through the
    # icon theme (app launchers) silently finds nothing, even though the file exists on disk. The 1024px
    # source is kept, just filed under the largest size hicolor actually advertises.
    install -Dm644 $src/soundcloud.png \
      $out/share/icons/hicolor/512x512/apps/soundcloud-rpc.png
  '';

  meta = {
    description = "SoundCloud Desktop Player with Discord RPC and MPRIS Integration";
    homepage = "https://github.com/Bebra-1337/soundcloud-rpc";
    license = lib.licenses.mit;
    mainProgram = "soundcloud-rpc";
    platforms = lib.platforms.linux;
  };
}
