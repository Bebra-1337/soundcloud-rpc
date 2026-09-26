{
  description = "SoundCloud Desktop Player with Discord RPC and MPRIS Integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      # `pkgs.soundcloud-rpc` after `nixpkgs.overlays = [ inputs.soundcloud-rpc.overlays.default ];`
      overlays.default = final: _prev: {
        soundcloud-rpc = final.callPackage ./package.nix { };
      };

      packages = forAllSystems (system: rec {
        soundcloud-rpc = (pkgsFor system).callPackage ./package.nix { };
        default = soundcloud-rpc;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${system}.default;
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          pythonEnv = pkgs.python3.withPackages (ps: with ps; [
            pyside6
            pypresence
          ]);
        in
        {
          default = pkgs.mkShell {
            packages = [ pythonEnv ];
            # QtQuick modules for the idle screen (the PySide6 wheel does not ship them)
            QML_IMPORT_PATH = "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
            shellHook = ''
              echo "SoundCloud RPC dev shell — run: python3 -m soundcloud_rpc"
            '';
          };
        }
      );
    };
}
