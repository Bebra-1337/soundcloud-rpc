# Dev shell for non-flake users: `nix-shell`
# Uses the same nixpkgs revision as flake.lock so both entry points stay in sync.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  locked = lock.nodes.nixpkgs.locked;
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  };
  pkgs = import nixpkgs { };
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pyside6
    pypresence
  ]);
in
pkgs.mkShell {
  packages = [ pythonEnv ];
  # QtQuick modules for the idle screen (the PySide6 wheel does not ship them)
  QML_IMPORT_PATH = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
  shellHook = ''
    echo "SoundCloud RPC dev shell — run: python3 -m soundcloud_rpc"
  '';
}
