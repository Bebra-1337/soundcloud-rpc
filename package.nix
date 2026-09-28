{
  lib,
  python3Packages,
  qt6,
  makeDesktopItem,
  copyDesktopItems,
}:

python3Packages.buildPythonApplication {
  pname = "soundcloud-rpc";
  version = "1.1.0";
  pyproject = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./pyproject.toml
      ./soundcloud_rpc
    ];
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    pyside6
    pypresence
  ];

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
    copyDesktopItems
  ];

  # qtdeclarative provides the QtQuick modules used by the idle screen; wrapQtAppsHook adds their
  # QML/plugin paths to the wrapper so no environment variables are needed at runtime.
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwebengine
    qt6.qtwayland
  ];

  # Wrap once, through the Python wrapper, instead of wrapping the entry point twice.
  dontWrapQtApps = true;
  preFixup = ''
    makeWrapperArgs+=("''${qtWrapperArgs[@]}")
  '';

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
    install -Dm644 soundcloud_rpc/soundcloud.png \
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
