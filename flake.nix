{
  description = "SoundCloud Desktop Player with Discord RPC and MPRIS Integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          pythonEnv = pkgs.python3.withPackages (ps: with ps; [
            pyside6
            pypresence
          ]);
          desktopItem = pkgs.makeDesktopItem {
            name = "soundcloud-rpc";
            desktopName = "SoundCloud Desktop";
            genericName = "Music Player";
            comment = "SoundCloud Desktop Player with Discord RPC and MPRIS Integration";
            exec = "soundcloud-rpc %U";
            icon = "soundcloud-rpc";
            terminal = false;
            type = "Application";
            categories = [ "AudioVideo" "Audio" "Player" "Music" ];
            startupWMClass = "soundcloud-rpc";
            keywords = [ "SoundCloud" "Music" "Player" "RPC" "Discord" "MPRIS" ];
          };
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "soundcloud-rpc";
            version = "1.0.0";

            src = ./.;

            nativeBuildInputs = [ pkgs.copyDesktopItems pkgs.makeWrapper ];

            desktopItems = [ desktopItem ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin $out/share/soundcloud-rpc $out/share/icons/hicolor/1024x1024/apps

              cp soundcloud_rpc.py $out/share/soundcloud-rpc/
              cp soundcloud.png $out/share/soundcloud-rpc/
              cp soundcloud.png $out/share/icons/hicolor/1024x1024/apps/soundcloud-rpc.png

              makeWrapper ${pythonEnv}/bin/python3 $out/bin/soundcloud-rpc \
                --add-flags "$out/share/soundcloud-rpc/soundcloud_rpc.py"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "SoundCloud Desktop Player with Discord RPC and MPRIS Integration";
              homepage = "https://github.com/Bebra-1337/soundcloud-rpc";
              license = licenses.mit;
              mainProgram = "soundcloud-rpc";
              platforms = platforms.linux;
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          pythonEnv = pkgs.python3.withPackages (ps: with ps; [
            pyside6
            pypresence
          ]);
        in
        {
          default = pkgs.mkShell {
            buildInputs = [ pythonEnv ];
          };
        }
      );
    };
}
