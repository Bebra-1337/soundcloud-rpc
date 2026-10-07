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
in
pkgs.mkShell {
  inputsFrom = [ (pkgs.callPackage ./package.nix { }) ];
  packages = with pkgs; [ clang-tools gdb ];
  shellHook = ''
    echo "SoundCloud RPC dev shell — build: cmake -B build -G Ninja && cmake --build build"
  '';
}
