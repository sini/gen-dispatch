# gen-dispatch REPL — all exports in scope. Run: nix repl --impure --file ci/repl.nix
#
# gen-dispatch is built from gen-prelude (nixpkgs-lib-free); prelude is resolved from the
# ci flake.lock. nixpkgs `lib` is still exposed for interactive convenience.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  inherit (nixpkgs) lib;
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  node = lock.nodes.gen-prelude.locked;
  prelude = import "${
    builtins.fetchTree {
      inherit (node)
        type
        owner
        repo
        rev
        narHash
        ;
    }
  }/lib";
  genDispatch = import ../lib { inherit prelude; };
in
{
  inherit lib prelude genDispatch;
}
// genDispatch
