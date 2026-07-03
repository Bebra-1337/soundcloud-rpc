{
  description = "SoundCloud Desktop Player with Discord RPC";

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
        in
        {
          default = pkgs.writeShellScriptBin "soundcloud-rpc" ''
            exec ${pythonEnv}/bin/python3 ${./soundcloud_rpc.py} "$@"
          '';
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
