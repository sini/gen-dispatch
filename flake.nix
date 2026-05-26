{
  description = "gen-derive: stratified rule dispatch with fixpoint convergence";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gen-algebra.url = "github:sini/gen-algebra";
  };

  outputs =
    {
      nixpkgs,
      gen-algebra,
      ...
    }:
    let
      deriveLib = import ./lib {
        lib = nixpkgs.lib;
        genPure = gen-algebra.pure;
      };
    in
    {
      lib = deriveLib;
    };
}
