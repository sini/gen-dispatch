# gen-derive REPL — all exports in scope.
let
  nixpkgs = import (builtins.getFlake "nixpkgs") { };
  inherit (nixpkgs) lib;
  deriveLib = import ../lib { inherit lib; };
in
{
  inherit lib deriveLib;
}
// deriveLib
