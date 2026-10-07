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
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [ clang-tools gdb ];
            shellHook = ''
              echo "SoundCloud RPC dev shell — build: cmake -B build -G Ninja && cmake --build build"
            '';
          };
        }
      );
    };
}
